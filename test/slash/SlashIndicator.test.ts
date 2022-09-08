import { expect } from 'chai';
import { ethers, network } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

import {
  SlashIndicator,
  SlashIndicator__factory,
  TransparentUpgradeableProxy__factory,
  MockValidatorSet__factory,
  MockValidatorSet,
} from '../../src/types';
import { Address } from 'hardhat-deploy/dist/types';

let slashContract: SlashIndicator;

let deployer: SignerWithAddress;
let proxyAdmin: SignerWithAddress;
let validatorContract: MockValidatorSet;
let vagabond: SignerWithAddress;
let coinbases: SignerWithAddress[];
let defaultCoinbase: Address;
let localIndicators: number[];

enum SlashType {
  UNKNOWN,
  MISDEMEANOR,
  FELONY,
  DOUBLE_SIGNING,
}

const resetCoinbase = async () => {
  await network.provider.send('hardhat_setCoinbase', [defaultCoinbase]);
};

const increaseLocalCounterForValidatorAt = async (_index: number, _increase?: number) => {
  _increase = _increase ?? 1;
  localIndicators[_index] += _increase;
};

const setLocalCounterForValidatorAt = async (_index: number, _value: number) => {
  localIndicators[_index] = _value;
};

const resetLocalCounterForValidatorAt = async (_index: number) => {
  localIndicators[_index] = 0;
};

const validateIndicatorAt = async (_index: number) => {
  expect(localIndicators[_index]).to.eq(await slashContract.getSlashIndicator(coinbases[_index].address));
};

const doSlash = async (slasher: SignerWithAddress, slashee: SignerWithAddress) => {
  return slashContract.connect(slasher).slash(slashee.address);
};

describe('Slash indicator test', () => {
  let felonyThreshold: number;
  let misdemeanorThreshold: number;

  before(async () => {
    [deployer, proxyAdmin, vagabond, ...coinbases] = await ethers.getSigners();

    localIndicators = Array<number>(coinbases.length).fill(0);

    const nonce = await deployer.getTransactionCount();
    const slashIndicatorAddr = ethers.utils.getContractAddress({ from: deployer.address, nonce: nonce + 2 });
    validatorContract = await new MockValidatorSet__factory(deployer).deploy(
      ethers.constants.AddressZero,
      slashIndicatorAddr,
      0,
      0
    );
    const logicContract = await new SlashIndicator__factory(deployer).deploy();
    const proxyContract = await new TransparentUpgradeableProxy__factory(deployer).deploy(
      logicContract.address,
      proxyAdmin.address,
      logicContract.interface.encodeFunctionData('initialize', [10, 20, validatorContract.address, 0, 0, 28800 * 2])
    );
    slashContract = SlashIndicator__factory.connect(proxyContract.address, deployer);

    let thresholds = await slashContract.getSlashThresholds();
    felonyThreshold = thresholds[0].toNumber();
    misdemeanorThreshold = thresholds[1].toNumber();

    defaultCoinbase = await network.provider.send('eth_coinbase');
  });

  describe('Single flow test', async () => {
    describe('Unauthorized test', async () => {
      it('Should non-coinbase cannot call slash', async () => {
        await expect(slashContract.connect(vagabond).slash(coinbases[0].address)).to.revertedWith(
          'SlashIndicator: method caller is not the coinbase'
        );
      });

      it('Should non-validatorContract cannot call reset counter', async () => {
        await expect(slashContract.connect(vagabond).resetCounters([coinbases[0].address])).to.revertedWith(
          'SlashIndicator: method caller is not the validator contract'
        );
      });
    });

    describe('Slash method: recording', async () => {
      it('Should slash a validator successfully', async () => {
        let slasherIdx = 0;
        let slasheeIdx = 1;
        await network.provider.send('hardhat_setCoinbase', [coinbases[slasherIdx].address]);

        let tx = await doSlash(coinbases[slasherIdx], coinbases[slasheeIdx]);
        expect(tx).to.not.emit(slashContract, 'ValidatorSlashed');
        setLocalCounterForValidatorAt(slasheeIdx, 1);
        validateIndicatorAt(slasheeIdx);
      });

      it('Should validator not be able to slash themselves', async () => {
        let slasherIdx = 0;
        let tx = await doSlash(coinbases[slasherIdx], coinbases[slasherIdx]);
        expect(tx).to.not.emit(slashContract, 'ValidatorSlashed');

        await resetLocalCounterForValidatorAt(slasherIdx);
        await validateIndicatorAt(slasherIdx);
      });

      it('Should not able to slash twice in one block', async () => {
        let slasherIdx = 0;
        let slasheeIdx = 2;
        await network.provider.send('evm_setAutomine', [false]);
        await doSlash(coinbases[slasherIdx], coinbases[slasheeIdx]);
        let tx = doSlash(coinbases[slasherIdx], coinbases[slasheeIdx]);
        await expect(tx).to.be.revertedWith(
          'SlashIndicator: cannot slash a validator twice or slash more than one validator in one block'
        );
        await network.provider.send('evm_mine');
        await network.provider.send('evm_setAutomine', [true]);

        await increaseLocalCounterForValidatorAt(slasheeIdx);
        await validateIndicatorAt(slasheeIdx);
      });

      it('Should not able to slash more than one validator in one block', async () => {
        let slasherIdx = 0;
        let slasheeIdx1 = 1;
        let slasheeIdx2 = 2;
        await network.provider.send('evm_setAutomine', [false]);
        await doSlash(coinbases[slasherIdx], coinbases[slasheeIdx1]);
        let tx = doSlash(coinbases[slasherIdx], coinbases[slasheeIdx2]);
        await expect(tx).to.be.revertedWith(
          'SlashIndicator: cannot slash a validator twice or slash more than one validator in one block'
        );
        await network.provider.send('evm_mine');
        await network.provider.send('evm_setAutomine', [true]);

        await increaseLocalCounterForValidatorAt(slasheeIdx1);
        await validateIndicatorAt(slasheeIdx1);
        await setLocalCounterForValidatorAt(slasheeIdx2, 1);
        await validateIndicatorAt(slasheeIdx1);
      });
    });

    describe('Slash method: recording and call to validator set', async () => {
      it('Should sync with validator set for felony', async () => {
        let tx;
        let slasherIdx = 0;
        let slasheeIdx = 3;

        await network.provider.send('hardhat_setCoinbase', [coinbases[slasherIdx].address]);

        for (let i = 0; i < felonyThreshold; i++) {
          tx = await doSlash(coinbases[slasherIdx], coinbases[slasheeIdx]);
        }
        expect(tx).to.emit(slashContract, 'ValidatorSlashed').withArgs(coinbases[1].address, SlashType.FELONY);
        await setLocalCounterForValidatorAt(slasheeIdx, felonyThreshold);
        await validateIndicatorAt(slasheeIdx);
      });

      it('Should sync with validator set for misdemeanor', async () => {
        let tx;
        let slasherIdx = 1;
        let slasheeIdx = 4;
        await network.provider.send('hardhat_setCoinbase', [coinbases[slasherIdx].address]);

        for (let i = 0; i < misdemeanorThreshold; i++) {
          tx = await doSlash(coinbases[slasherIdx], coinbases[slasheeIdx]);
        }
        expect(tx).to.emit(slashContract, 'ValidatorSlashed').withArgs(coinbases[1].address, SlashType.MISDEMEANOR);
        await setLocalCounterForValidatorAt(slasheeIdx, misdemeanorThreshold);
        await validateIndicatorAt(slasheeIdx);
      });
    });

    describe('Resetting counter', async () => {
      it('Should validator set contract reset counter for one validator', async () => {
        let tx;
        let slasherIdx = 0;
        let slasheeIdx = 5;
        let numberOfSlashing = felonyThreshold - 1;
        await network.provider.send('hardhat_setCoinbase', [coinbases[slasherIdx].address]);

        for (let i = 0; i < numberOfSlashing; i++) {
          await doSlash(coinbases[slasherIdx], coinbases[slasheeIdx]);
        }
        await setLocalCounterForValidatorAt(slasheeIdx, numberOfSlashing);
        await validateIndicatorAt(slasheeIdx);

        await resetCoinbase();

        tx = await validatorContract.resetCounters([coinbases[slasheeIdx].address]);
        expect(tx).to.emit(slashContract, 'UnavailabilityIndicatorReset').withArgs(coinbases[slasheeIdx].address);

        await resetLocalCounterForValidatorAt(slasheeIdx);
        await validateIndicatorAt(slasheeIdx);
      });

      it('Should validator set contract reset counter for multiple validators', async () => {
        let tx;
        let slasherIdx = 0;
        let slasheeIdxs = [6, 7, 8, 9, 10];
        let numberOfSlashing = felonyThreshold - 1;
        await network.provider.send('hardhat_setCoinbase', [coinbases[slasherIdx].address]);

        for (let i = 0; i < numberOfSlashing; i++) {
          for (let j = 0; j < slasheeIdxs.length; j++) {
            await doSlash(coinbases[slasherIdx], coinbases[slasheeIdxs[j]]);
          }
        }

        for (let j = 0; j < slasheeIdxs.length; j++) {
          await setLocalCounterForValidatorAt(slasheeIdxs[j], numberOfSlashing);
          await validateIndicatorAt(slasheeIdxs[j]);
        }

        await resetCoinbase();

        tx = await validatorContract.resetCounters(slasheeIdxs.map((_) => coinbases[_].address));

        for (let j = 0; j < slasheeIdxs.length; j++) {
          expect(tx).to.emit(slashContract, 'UnavailabilityIndicatorReset').withArgs(coinbases[slasheeIdxs[j]].address);
          await resetLocalCounterForValidatorAt(slasheeIdxs[j]);
          await validateIndicatorAt(slasheeIdxs[j]);
        }
      });
    });
  });

  describe('Integration test', async () => {});
});
