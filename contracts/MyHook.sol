// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "@uniswap/v4-core/contracts/interfaces/IPoolManager.sol";
import "./Proxy.sol";
import {PoolKey} from "@uniswap/v4-core/contracts/types/PoolId.sol";
import {IPoolManager} from "@uniswap/v4-core/contracts/PoolManager.sol";
import "hardhat/console.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/contracts/types/Currency.sol";

import "./Hyperlane/IMailbox.sol";
import "./Hyperlane/IInterchainGasPayMaster.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "./ISM/IEmptyIsm.sol";
import "./ISM/IMultisigISM.sol";
import "./IUniswapInteract.sol";
import "./Hooks/Utils/BaseHook.sol";

contract MyHook is BaseHook {
    //Hook Stuff
    uint32 deployTimestamp;
    uint256 public counterBeforeSwap;
    uint256 public counterBeforeInit;
    uint256 public counterAfterSwap;

    //Uniswap Trade Stuff
    UniswapInteract public immutable uniswapInteract;
    // IPoolManager public immutable override poolManager;
    Proxy public proxyToken;
    address public proxyAddy;
    //PoolKey public poolKey;
    mapping(address => PoolKey) public tokenToKey;

    mapping(address => bool) public approvedToken;

    uint256 public count;

    //Hyperlane Stuff:
    mapping(uint256 => address) public domainToAddress; //Domain to Manager address
    IMailbox public immutable mailBox;
    IInterchainGasPaymaster public immutable igp;
    address public ism;
    uint32 domain = 0;

    constructor(
        address _uI,
        address _poolManager,
        address _mailBox,
        address _igp
    ) BaseHook(IPoolManager(_poolManager)) {
        uniswapInteract = UniswapInteract(_uI);
        // poolManager = IPoolManager(_poolManager);
        mailBox = IMailbox(_mailBox);
        igp = IInterchainGasPaymaster(_igp);
    }

    function setProxyToken(address _proxyToken) public {
        proxyToken = Proxy(_proxyToken);
        proxyAddy = _proxyToken;
    }

    function setISM(address _newISM) public {
        ism = _newISM;
    }

    function addDomain(uint256 domain, address managerAddress) public {
        domainToAddress[domain] = managerAddress;
    }

    function initializeProxyPool(
        address otherToken,
        uint160 sqrtPRice,
        bytes memory hookData
    ) public {
        PoolKey memory myKey;

        if (otherToken < proxyAddy) {
            myKey = PoolKey(
                Currency.wrap(otherToken),
                Currency.wrap(proxyAddy),
                3000,
                60,
                IHooks(0x0000000000000000000000000000000000000000)
            );
        } else {
            myKey = PoolKey(
                Currency.wrap(proxyAddy),
                Currency.wrap(otherToken),
                3000,
                60,
                IHooks(address(this))
            );
        }
        poolManager.initialize(myKey, sqrtPRice, hookData);
        tokenToKey[otherToken] = myKey;
    }

    function createPosition(
        address token,
        uint256 tokenAmount,
        int24 lower,
        int24 upper
    ) public {
        TransferHelper.safeTransferFrom(
            token,
            msg.sender,
            address(this),
            tokenAmount
        );
        uint128 liquidity = 0;
        uint160 sqrtA = TickMath.getSqrtRatioAtTick(lower);
        uint160 sqrtB = TickMath.getSqrtRatioAtTick(upper);
        if (token < proxyAddy) {
            //token is 0
            liquidity = LiquidityAmounts.getLiquidityForAmount0(
                sqrtA,
                sqrtB,
                tokenAmount
            );
        } else {
            liquidity = LiquidityAmounts.getLiquidityForAmount1(
                sqrtA,
                sqrtB,
                tokenAmount
            );
        }
        //uniswapInteract
        uint256 bigAmount = 1000000000000000000000000000;
        proxyToken.mint(bigAmount);
        TransferHelper.safeTransfer(
            proxyAddy,
            address(uniswapInteract),
            bigAmount
        );
        TransferHelper.safeTransfer(
            (token),
            address(uniswapInteract),
            tokenAmount
        );
        (uint256 t0Amount, uint256 t1Amount) = uniswapInteract.addLiquidity(
            tokenToKey[token],
            IPoolManager.ModifyPositionParams(lower, upper, int128(liquidity)),
            block.timestamp + 10000000
        );
        if (token < proxyAddy) {
            //token is 0
            TransferHelper.safeTransfer(address(token), msg.sender, t0Amount);
            proxyToken.burn(bigAmount - t1Amount);
        } else {
            //token is 1
            TransferHelper.safeTransfer(address(token), msg.sender, t1Amount);
            proxyToken.burn(bigAmount - t0Amount);
        }
    }

    function closePosition(
        address token,
        int24 lower,
        int24 upper
    ) public returns (uint256) {
        (int128 t0Amount, int128 t1Amount) = uniswapInteract.closePosition(
            tokenToKey[token],
            lower,
            upper,
            block.timestamp + 100000000
        );
        if (token < proxyAddy) {
            //token is 0
            //transfer to user??
            TransferHelper.safeTransfer(
                address(Currency.unwrap(tokenToKey[token].currency0)),
                msg.sender,
                uint128(-t0Amount)
            );
            proxyToken.burn(uint128(-t1Amount));
            console.log("Earend:", uint128(-t1Amount));
            return uint128(-t0Amount);
        } else {
            TransferHelper.safeTransfer(
                address(Currency.unwrap(tokenToKey[token].currency1)),
                msg.sender,
                uint128(-t1Amount)
            );
            console.log("Earend:", uint128(-t0Amount));

            proxyToken.burn(uint128(-t0Amount));
            return uint128(-t1Amount);
        }
    }

    //zeroForOne - true - 4295128740
    //zeroForOne - false - 1461446703485210103287273052203988822378723970342
    function swap(address token, bool toProxy, uint256 tokenAmount) public {
        TransferHelper.safeTransferFrom(
            token,
            msg.sender,
            address(this),
            tokenAmount
        );
        //uniswapInteract
        bool zeroForOne;
        if (token < proxyAddy) {
            //token is 0
            zeroForOne = true;
            zeroForOne == toProxy ? true : false;
        } else {
            zeroForOne = false;
            zeroForOne == toProxy ? false : true;
        }
        TransferHelper.safeTransfer(
            token,
            address(uniswapInteract),
            tokenAmount
        );
        uint256 balBeforeProxy = IERC20(proxyAddy).balanceOf(address(this));
        uint256 balBeforeToken = IERC20(token).balanceOf(address(this));

        uniswapInteract.swap(
            tokenToKey[token],
            IPoolManager.SwapParams(
                zeroForOne,
                int256(tokenAmount),
                zeroForOne
                    ? 4295128740
                    : 1461446703485210103287273052203988822378723970341
            ),
            block.timestamp + 10000000
        );
        if (balBeforeToken < IERC20(token).balanceOf(address(this))) {
            TransferHelper.safeTransfer(
                token,
                msg.sender,
                IERC20(token).balanceOf(address(this)) - balBeforeToken
            );
        }
        if (balBeforeProxy < IERC20(proxyAddy).balanceOf(address(this))) {
            TransferHelper.safeTransfer(
                proxyAddy,
                msg.sender,
                IERC20(proxyAddy).balanceOf(address(this)) - balBeforeProxy
            );
        }
    }

    function swapToOtherChain(
        address token,
        uint256 tokenAmount,
        uint32 domainGoal,
        address endingAsset,
        address endingAddress
    ) public payable {
        TransferHelper.safeTransferFrom(
            token,
            msg.sender,
            address(this),
            tokenAmount
        );
        bool zeroForOne;
        bool toProxy = true;
        if (token < proxyAddy) {
            //token is 0
            zeroForOne = true;
            zeroForOne == toProxy ? true : false;
        } else {
            zeroForOne = false;
            zeroForOne == toProxy ? false : true;
        }
        TransferHelper.safeTransfer(
            token,
            address(uniswapInteract),
            tokenAmount
        );
        (int256 t0, int256 t1) = uniswapInteract.swap(
            tokenToKey[token],
            IPoolManager.SwapParams(
                zeroForOne,
                int256(tokenAmount),
                zeroForOne
                    ? 4295128740
                    : 1461446703485210103287273052203988822378723970341
            ),
            block.timestamp + 10000000
        );
        console.log(uint256(-t0), uint256(t1));
        //Now transfer the amount of proxy tokens that they just earend
        if (toProxy) {
            //token is 0
            if (zeroForOne) {
                proxyAmount = uint256(-t1);
            } else {
                proxyAmount = uint256(-t0);
            }
        }
        //proxyToken.burn(proxyAmount);
        bytes32 _messageId = mailBox.dispatch(
            domainGoal,
            addressToBytes32(domainToAddress[domainGoal]),
            abi.encode(
                abi.encode(proxyAmount, endingAsset, endingAddress),
                0,
                msg.sender
            )
        );

        //Pay from the contract's balance
        igp.payForGas{value: msg.value}(
            _messageId, // The ID of the message that was just dispatched
            domainGoal, // The destination domain of the message
            200000,
            address(this) // refunds are returned to this contract
        );
    }

    uint256 public proxyAmount;

    function handle(
        uint32 _origin,
        bytes32 _sender,
        bytes calldata _body
    ) external {
        count++;
        //Decompose the data
        bool toProxy = false;
        (bytes memory data, uint8 action, address user) = abi.decode(
            _body,
            (bytes, uint8, address)
        );
        if (action == 0) {
            (
                uint256 _proxyAmount,
                address desiredAsset,
                address endingAddress
            ) = abi.decode(data, (uint256, address, address));
            if (action == 0) {
                //address token, bool toProxy, uint256 tokenAmount
                proxyToken.mint(_proxyAmount);
                uint256 balBefore = IERC20(desiredAsset).balanceOf(
                    address(this)
                );
                //         uint256 balBeforeToken = IERC20(desiredAsset).balanceOf(
                //             address(this)
                //         );
                //uniswapInteract
                bool zeroForOne;
                if (desiredAsset < proxyAddy) {
                    //token is 0
                    zeroForOne = false;
                } else {
                    zeroForOne = true;
                }
                TransferHelper.safeTransfer(
                    proxyAddy,
                    address(uniswapInteract),
                    _proxyAmount
                );

                uniswapInteract.swap(
                    tokenToKey[desiredAsset],
                    IPoolManager.SwapParams(
                        zeroForOne,
                        int256(_proxyAmount),
                        zeroForOne
                            ? 4295128740
                            : 1461446703485210103287273052203988822378723970341
                    ),
                    block.timestamp + 10000000
                );

                uint256 balAfter = IERC20(desiredAsset).balanceOf(
                    address(this)
                );
                if (balAfter > balBefore) {
                    TransferHelper.safeTransfer(
                        desiredAsset,
                        endingAddress,
                        balAfter - balBefore
                    );
                }
            }
        }
        if (action == 1) {
            (uint256 boostPerSwap, uint256 totalAmount) = abi.decode(
                data,
                (uint256, uint256)
            );
            totalBoostPerSwapDomain[domain] += totalAmount;
            boostPerSwapDomain[domain] += boostPerSwap;
        }
    }

    // function handle(
    //     uint256 _proxyAmount,
    //     address desiredAsset,
    //     address endingAddress,
    //     uint8 action
    // ) external {
    //     count++;
    //     //Decompose the data

    //     if (action == 0) {
    //         //address token, bool toProxy, uint256 tokenAmount
    //         proxyToken.mint(_proxyAmount);
    //         uint256 balBefore = IERC20(desiredAsset).balanceOf(address(this));
    //         //         uint256 balBeforeToken = IERC20(desiredAsset).balanceOf(
    //         //             address(this)
    //         //         );
    //         swap(desiredAsset, false, _proxyAmount);

    //         uint256 balAfter = IERC20(desiredAsset).balanceOf(address(this));
    //         if (balAfter > balBefore) {
    //             TransferHelper.safeTransfer(
    //                 desiredAsset,
    //                 endingAddress,
    //                 balAfter - balBefore
    //             );
    //         }
    //     }
    // }

    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }

    function poke(uint32 domain) public payable {
        uint256 gasAmount = 100000;
        bytes32 _messageId = mailBox.dispatch(
            domain,
            addressToBytes32(domainToAddress[domain]),
            abi.encode(msg.sender)
            //abi.encode(message)
        );

        // Pay from the contract's balance
        igp.payForGas{value: msg.value}(
            _messageId, // The ID of the message that was just dispatched
            domain, // The destination domain of the message
            gasAmount,
            address(this) // refunds are returned to this contract
        );
    }

    function interchainSecurityModule() external view returns (address) {
        return ism;
    }

    function getFee(
        address,
        PoolKey calldata,
        IPoolManager.SwapParams calldata,
        bytes calldata
    ) external view returns (uint24) {
        uint24 startingFee = 3000;
        uint32 lapsed = _blockTimestamp() - deployTimestamp;
        return startingFee + (uint24(lapsed) * 100) / 60; // 100 bps a minute
    }

    struct boostInfo {
        uint256 swapCount;
        uint256 boostID;
        uint256 boostPerSwap;
        address owner;
    }
    uint256 boostID;
    mapping(uint256 => boostInfo) public idToInfo;
    mapping(uint32 => uint256) public totalBoostPerSwapDomain;
    mapping(address => uint256) public totalBoostPerSwapToken;
    mapping(uint32 => uint256) public boostPerSwapDomain;
    mapping(address => uint256) public boostPerSwapToken;

    function createBoost(
        uint256 swapCount,
        uint256 boostPerSwap,
        address[] memory approvedTokens,
        uint32[] memory approvedDomains
    ) public {
        console.log("AMount:", swapCount * boostPerSwap);
        TransferHelper.safeTransferFrom(
            proxyAddy,
            msg.sender,
            address(this),
            swapCount * boostPerSwap
        );

        idToInfo[boostID] = boostInfo(
            swapCount,
            boostID,
            boostPerSwap,
            msg.sender
        );
        for (uint i = 0; i < approvedTokens.length; i++) {
            boostPerSwapToken[approvedTokens[i]] += boostPerSwap;

            totalBoostPerSwapToken[approvedTokens[i]] +=
                boostPerSwap *
                swapCount;
        }
    }

    function createBoostDomain(
        uint256 swapCount,
        uint256 boostPerSwap,
        uint32[] memory approvedDomains
    ) public {
        TransferHelper.safeTransferFrom(
            proxyAddy,
            msg.sender,
            address(this),
            swapCount * boostPerSwap
        );

        idToInfo[boostID] = boostInfo(
            swapCount,
            boostID,
            boostPerSwap,
            msg.sender
        );
        for (uint i = 0; i < approvedDomains.length; i++) {
            bytes32 _messageId = mailBox.dispatch(
                approvedDomains[i],
                addressToBytes32(domainToAddress[approvedDomains[i]]),
                abi.encode(
                    abi.encode(boostPerSwap, boostPerSwap * swapCount),
                    1,
                    msg.sender
                )
            );

            // Pay from the contract's balance
            igp.payForGas{value: 2000000000000000}(
                _messageId, // The ID of the message that was just dispatched
                approvedDomains[i], // The destination domain of the message
                100000,
                address(this) // refunds are returned to this contract
            );
        }
    }

    function beforeSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        bytes calldata hookData
    ) external override returns (bytes4) {
        console.log("Before Swap");
        counterBeforeSwap++;
        address token = Currency.unwrap(key.currency0) == proxyAddy
            ? Currency.unwrap(key.currency1)
            : Currency.unwrap(key.currency0);

        uint256 boost = boostPerSwapToken[token] + boostPerSwapDomain[domain];
        console.log(boost, "is boost amount");
        TransferHelper.safeTransfer(proxyAddy, address(uniswapInteract), boost);
        if (
            boost >
            totalBoostPerSwapToken[token] + totalBoostPerSwapDomain[domain]
        ) {
            return this.beforeSwap.selector;
        }
        if (boost > 0) {
            if (token < proxyAddy) {
                uniswapInteract.donate(
                    tokenToKey[token],
                    0,
                    boost,
                    block.timestamp + 100000000
                );
            } else {
                console.log(IERC20(token).balanceOf(address(uniswapInteract)));
                uniswapInteract.donate(
                    tokenToKey[token],
                    boost,
                    0,
                    block.timestamp + 10000000
                );
                console.log(IERC20(token).balanceOf(address(uniswapInteract)));

                console.log("Fin");
            }
        }

        totalBoostPerSwapToken[token] -= boostPerSwapToken[token];
        // totalBoostPerSwapDomain[domain] -= totalBoostPerSwapDomain[domain];

        return this.beforeSwap.selector;
    }

    function afterSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata hookData
    ) external override returns (bytes4) {
        counterAfterSwap++;
        // (uint32 domainGoal, address targetAddy, uint256 _proxyAmount) = abi
        //     .decode(hookData, (uint32, address, uint256));
        // bytes32 _messageId = mailBox.dispatch(
        //     domainGoal,
        //     addressToBytes32(targetAddy),
        //     abi.encode(abi.encode(_proxyAmount), sender)
        //     //abi.encode(message)
        // );

        // // Pay from the contract's balance
        // igp.payForGas{value: 2000000000000000}(
        //     _messageId, // The ID of the message that was just dispatched
        //     domain, // The destination domain of the message
        //     100000,
        //     address(this) // refunds are returned to this contract
        // );

        //I could execute this after a swap, and it would check the direction

        return this.afterSwap.selector;
    }

    //function getTokenPrice() view returns () {}
    //Fancy way to get tokenPriec

    function beforeInitialize(
        address sender,
        PoolKey calldata key,
        uint160 sqrtPriceX96,
        bytes calldata hookData
    ) external override returns (bytes4) {
        counterBeforeInit++;
        require(sender == address(this));
        //require(sqrtPriceX96 == )

        return this.beforeInitialize.selector;
    }

    /// @dev For mocking
    function _blockTimestamp() internal view virtual returns (uint32) {
        return uint32(block.timestamp);
    }

    function getHooksCalls() public pure override returns (Hooks.Calls memory) {
        return
            Hooks.Calls({
                beforeInitialize: true,
                afterInitialize: false,
                beforeModifyPosition: false,
                afterModifyPosition: false,
                beforeSwap: true,
                afterSwap: true,
                beforeDonate: false,
                afterDonate: false
            });
    }

    receive() external payable {}
}
