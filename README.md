# UniswapV4Hardhat

This hardhat project will help anyone get started with Uniswap V4. It was based on the work I had done after two hackathons in using Uniswap V4.

The creation of this repo was mostly inspired by the lack of existing examples for hardhat for Uniswap V4. The documentation will be somewhat lacking on this page because there are already numerous articles and repos that explain Uniswap V4. There are some notes that I have within the repo itself.

It's also important to note that this protocol uses the version of Uniswap V4 right before they changed to Tstore and TLoad so some of the functions are different from the current repo. Therefore, the goal of this repo is mostly to allow for developers to experiment with hooks in a hardhat environment.

# Hardhat Deploy

This project uses hardhat deploy instead of regular hardhat because I have found it to be more convenient to use. The main difference is that this project has a deploy directory, which contains all of the deploy scripts. One of which (01-find-hook.js) is used to find the correct hook address. Each of the scripts are executed in terms of their numbers(e.g 00 is first then 01)

# UniswapInteract

This is the contract that is used to interact with the PoolManager contract to handle the lock. This was my interpretation on handling the lock; however, there are many other solutions in other repos. This one uses approvals, and it allows for most functionality.

# Utils

This folder contains two scripts. One is useful when initializing a token pair and the other is helpful for verifying contracts.
# Set up

This Set Up provides instructions for cloning the repository, installing dependencies, and running tests using either `npm` or `yarn`.

### Step 1: Clone the Repository
First, clone the UniswapV4Hardhat repository to your local machine:
```
git clone https://github.com/Gnome101/UniswapV4Hardhat.git
cd UniswapV4Hardhat
```
### Step 2: Install Dependencies

#### Using npm:
If you are using npm, install the dependencies with the following command:
```
npm install
```
#### Using yarn:
For yarn users, use this command instead:
```
yarn install
```
### Step 3: Run Tests

#### Using npm:
To run tests with npm, use the `npx` command:
```
npx hardhat test
```
#### Using yarn:
Yarn users can run tests with this command:
```
yarn hardhat test
```
