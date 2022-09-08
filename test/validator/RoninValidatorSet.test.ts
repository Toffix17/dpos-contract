import { expect } from 'chai';
import { BigNumber } from 'ethers';
import { ethers, network } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

import {
  DPoStaking,
  MockRoninValidatorSetEpochSetter,
  MockRoninValidatorSetEpochSetter__factory,
  DPoStaking__factory,
  TransparentUpgradeableProxy__factory,
  MockSlashIndicator,
  MockSlashIndicator__factory,
} from '../../src/types';

let roninValidatorSet: MockRoninValidatorSetEpochSetter;
let stakingContract: DPoStaking;
let slashIndicator: MockSlashIndicator;

let coinbase: SignerWithAddress;
let treasury: SignerWithAddress;
let deployer: SignerWithAddress;
let governanceAdmin: SignerWithAddress;
let proxyAdmin: SignerWithAddress;
let validatorCandidates: SignerWithAddress[];

const slashFelonyAmount = 100;
const slashDoubleSignAmount = 1000;
const maxValidatorNumber = 4;
const minValidatorBalance = BigNumber.from(2);

const mineBatchTxs = async (fn: () => Promise<void>) => {
  await network.provider.send('evm_setAutomine', [false]);
  await fn();
  await network.provider.send('evm_mine');
  await network.provider.send('evm_setAutomine', [true]);
};

describe('Ronin Validator Set test', () => {
  before(async () => {
    [coinbase, treasury, deployer, proxyAdmin, governanceAdmin, ...validatorCandidates] = await ethers.getSigners();
    validatorCandidates = validatorCandidates.slice(0, 5);
    await network.provider.send('hardhat_setCoinbase', [coinbase.address]);

    const nonce = await deployer.getTransactionCount();
    const roninValidatorSetAddr = ethers.utils.getContractAddress({ from: deployer.address, nonce: nonce + 1 });
    const stakingContractAddr = ethers.utils.getContractAddress({ from: deployer.address, nonce: nonce + 3 });

    slashIndicator = await new MockSlashIndicator__factory(deployer).deploy(
      roninValidatorSetAddr,
      slashFelonyAmount,
      slashDoubleSignAmount
    );
    await slashIndicator.deployed();

    roninValidatorSet = await new MockRoninValidatorSetEpochSetter__factory(deployer).deploy(
      governanceAdmin.address,
      slashIndicator.address,
      stakingContractAddr,
      maxValidatorNumber
    );
    await roninValidatorSet.deployed();

    const logicContract = await new DPoStaking__factory(deployer).deploy();
    await logicContract.deployed();

    const proxyContract = await new TransparentUpgradeableProxy__factory(deployer).deploy(
      logicContract.address,
      proxyAdmin.address,
      logicContract.interface.encodeFunctionData('initialize', [
        roninValidatorSet.address,
        governanceAdmin.address,
        100,
        minValidatorBalance,
      ])
    );
    await proxyContract.deployed();
    stakingContract = DPoStaking__factory.connect(proxyContract.address, deployer);

    expect(roninValidatorSetAddr.toLowerCase()).eq(roninValidatorSet.address.toLowerCase());
    expect(stakingContractAddr.toLowerCase()).eq(stakingContract.address.toLowerCase());
  });

  after(async () => {
    await network.provider.send('hardhat_setCoinbase', [ethers.constants.AddressZero]);
  });

  it('Should not be able to wrap up epoch using unauthorized account', async () => {
    await expect(roninValidatorSet.connect(deployer).wrapUpEpoch()).revertedWith(
      'RoninValidatorSet: method caller must be coinbase'
    );
  });

  it('Should not be able to wrap up epoch when the epoch is not ending', async () => {
    await expect(roninValidatorSet.connect(coinbase).wrapUpEpoch()).revertedWith(
      'RoninValidatorSet: only allowed at the end of epoch'
    );
  });

  it('Should be able to wrap up epoch when the epoch is ending', async () => {
    await mineBatchTxs(async () => {
      await roninValidatorSet.endEpoch();
      await roninValidatorSet.connect(coinbase).wrapUpEpoch();
    });
    expect(await roninValidatorSet.getValidators()).have.same.members([]);
  });

  it('Should be able to wrap up epoch and sync validator set from staking contract', async () => {
    for (let i = 0; i <= 3; i++) {
      await stakingContract
        .connect(validatorCandidates[i])
        .proposeValidator(validatorCandidates[i].address, validatorCandidates[i].address, 2_00, {
          value: minValidatorBalance.add(i),
        });
    }

    await mineBatchTxs(async () => {
      await roninValidatorSet.endEpoch();
      await roninValidatorSet.connect(coinbase).wrapUpEpoch();
    });

    expect(await roninValidatorSet.getValidators()).have.same.members(
      validatorCandidates
        .slice(0, 4)
        .reverse()
        .map((_) => _.address)
    );
  });

  it(`Should be able to wrap up epoch and pick top ${maxValidatorNumber} to be validators`, async () => {
    await stakingContract
      .connect(coinbase)
      .proposeValidator(coinbase.address, treasury.address, 1_00 /* 1% */, { value: 100 });
    for (let i = 4; i < validatorCandidates.length; i++) {
      await stakingContract
        .connect(validatorCandidates[i])
        .proposeValidator(validatorCandidates[i].address, validatorCandidates[i].address, 2_00, {
          value: minValidatorBalance.add(i),
        });
    }
    expect((await stakingContract.getValidatorCandidates()).length).eq(validatorCandidates.length + 1);

    await mineBatchTxs(async () => {
      await roninValidatorSet.endEpoch();
      await roninValidatorSet.connect(coinbase).wrapUpEpoch();
    });

    expect(await roninValidatorSet.getValidators()).have.same.members([
      coinbase.address,
      ...validatorCandidates
        .slice(2)
        .reverse()
        .map((_) => _.address),
    ]);
  });

  it('Should not be able to submit block reward using unauthorized account', async () => {
    await expect(roninValidatorSet.submitBlockReward()).revertedWith(
      'RoninValidatorSet: method caller must be coinbase'
    );
  });

  it('Should be able to submit block reward using coinbase account', async () => {
    await roninValidatorSet.connect(coinbase).submitBlockReward({ value: 100 });
  });

  it('Should be able to get right reward at the end of period', async () => {
    const balance = await treasury.getBalance();
    await mineBatchTxs(async () => {
      await roninValidatorSet.endEpoch();
      await roninValidatorSet.endPeriod();
      await roninValidatorSet.connect(coinbase).wrapUpEpoch();
    });
    const balanceDiff = (await treasury.getBalance()).sub(balance);
    expect(balanceDiff).eq(1); // 100 * 1%
    expect(await stakingContract.getClaimableReward(coinbase.address, coinbase.address)).eq(99); // remain amount (99%)
  });

  it('Should not allocate minting fee for the slashed validators', async () => {
    {
      const balance = await treasury.getBalance();
      await roninValidatorSet.connect(coinbase).submitBlockReward({ value: 100 });
      await slashIndicator.slashMisdemeanor(coinbase.address);
      await mineBatchTxs(async () => {
        await roninValidatorSet.endEpoch();
        await roninValidatorSet.connect(coinbase).wrapUpEpoch();
      });
      const balanceDiff = (await treasury.getBalance()).sub(balance);
      expect(balanceDiff).eq(0);
      // The delegators don't receives the new rewards until the period is ended
      expect(await stakingContract.getClaimableReward(coinbase.address, coinbase.address)).eq(99);
    }

    {
      const balance = await treasury.getBalance();
      await roninValidatorSet.connect(coinbase).submitBlockReward({ value: 100 });
      await mineBatchTxs(async () => {
        await roninValidatorSet.endEpoch();
        await roninValidatorSet.endPeriod();
        await roninValidatorSet.connect(coinbase).wrapUpEpoch();
      });
      const balanceDiff = (await treasury.getBalance()).sub(balance);
      expect(balanceDiff).eq(0);
      expect(await stakingContract.getClaimableReward(coinbase.address, coinbase.address)).eq(99);
    }
  });

  it('Should be able to record delegating reward for a successful epoch', async () => {
    const balance = await treasury.getBalance();
    await roninValidatorSet.connect(coinbase).submitBlockReward({ value: 100 });
    await mineBatchTxs(async () => {
      await roninValidatorSet.endEpoch();
      await roninValidatorSet.connect(coinbase).wrapUpEpoch();
    });
    const balanceDiff = (await treasury.getBalance()).sub(balance);
    expect(balanceDiff).eq(0);
    expect(await stakingContract.getClaimableReward(coinbase.address, coinbase.address)).eq(99 * 2);
  });

  it('Should not allocate reward for the slashed validator', async () => {
    const balance = await treasury.getBalance();
    await roninValidatorSet.connect(coinbase).submitBlockReward({ value: 100 });
    await slashIndicator.slashMisdemeanor(coinbase.address);
    await mineBatchTxs(async () => {
      await roninValidatorSet.endEpoch();
      await roninValidatorSet.endPeriod();
      await roninValidatorSet.connect(coinbase).wrapUpEpoch();
    });
    const balanceDiff = (await treasury.getBalance()).sub(balance);
    expect(balanceDiff).eq(0);
    expect(await stakingContract.getClaimableReward(coinbase.address, coinbase.address)).eq(99 * 2);
  });
});
