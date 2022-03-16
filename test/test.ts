import { ethers, network } from "hardhat";
import { BigNumber, Contract } from "ethers";
import { expect } from "chai";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

let owner: SignerWithAddress, 
	trader1: SignerWithAddress, 
	trader2: SignerWithAddress, 
	trader3: SignerWithAddress, 
	trader4: SignerWithAddress, 
	trader5: SignerWithAddress, 
	trader6: SignerWithAddress;

let token : Contract;
let finance: Contract;


before(async function () {
	let accounts: SignerWithAddress[] = await ethers.getSigners();
	[owner, trader1, trader2, trader3, trader4, trader5, trader6] = accounts;
	
	const RewardToken = await ethers.getContractFactory('RewardToken');
	token = await RewardToken.deploy();

	const Finance = await ethers.getContractFactory('Finance');
	finance = await Finance.deploy(token.address);

	console.log('Token:', token.address);
	console.log('Finance:', finance.address);

	token.transfer(finance.address, ethers.utils.parseEther('10000000'));
})

describe('Finance Test', function() {
	it('Period1', async function() {
		await finance.trade(trader1.address, ethers.utils.parseEther('100000'), new Date(2022, 2, 23).getTime() / 1000);
		await finance.trade(trader2.address, ethers.utils.parseEther('50000'), new Date(2022, 2, 24).getTime() / 1000);
		await finance.trade(trader3.address, ethers.utils.parseEther('100000'), new Date(2022, 2, 25).getTime() / 1000);
		await finance.trade(trader2.address, ethers.utils.parseEther('25000'), new Date(2022, 2, 26).getTime() / 1000);
	})
	it('Period2', async function() {
		await finance.trade(trader4.address, ethers.utils.parseEther('100000'), new Date(2022, 3, 21).getTime() / 1000);
		await finance.trade(trader2.address, ethers.utils.parseEther('25000'), new Date(2022, 3, 22).getTime() / 1000);
	})
	it('Period3', async function() {
		await finance.trade(trader1.address, ethers.utils.parseEther('100000'), new Date(2022, 4, 21).getTime() / 1000);
	})
	it('Period4', async function() {
	})
	it('Period5', async function() {
		await finance.claim(trader1.address);
		await finance.claim(trader2.address);
		await finance.claim(trader3.address);
		await finance.claim(trader4.address);
	})
})