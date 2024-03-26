// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { LibErrorHandler } from "contract-libs/LibErrorHandler.sol";
import "./20231003_REP002AndREP003_RON_NonConditional_Wrapup2Periods.s.sol";
import { BridgeRewardDeploy } from "script/contracts/BridgeRewardDeploy.s.sol";
import { BridgeSlashDeploy } from "script/contracts/BridgeSlashDeploy.s.sol";
import { RoninBridgeManagerDeploy } from "script/contracts/RoninBridgeManagerDeploy.s.sol";

import { RoninGatewayV3 } from "@ronin/contracts/ronin/gateway/RoninGatewayV3.sol";
import { BridgeReward } from "@ronin/contracts/ronin/gateway/BridgeReward.sol";
import { BridgeSlash } from "@ronin/contracts/ronin/gateway/BridgeSlash.sol";
import { RoninBridgeManager } from "@ronin/contracts/ronin/gateway/RoninBridgeManager.sol";
import { BridgeTracking } from "@ronin/contracts/ronin/gateway/BridgeTracking.sol";
import { TransparentUpgradeableProxyV2 } from "@ronin/contracts/extensions/TransparentUpgradeableProxyV2.sol";

contract Simulation_20231003_REP002AndREP003_RON_NonConditional_GatewayUpgrade_Approve is
  Simulation__20231003_UpgradeREP002AndREP003_RON_NonConditional_Wrapup2Periods
{
  using LibErrorHandler for bool;

  function _hookSetDepositCount() internal pure override returns (uint256) {
    return 42678; // fork-block-number 28598979
  }

  function _hookPrankOperator() internal pure override returns (address) {
    return 0x4b3844A29CFA5824F53e2137Edb6dc2b54501BeA;
    // return 0x32015E8B982c61bc8a593816FdBf03A603EEC823;
  }

  function _afterDepositForOnlyOnRonin(Transfer.Receipt memory receipt) internal override {
    address[21] memory operators = [
      // 0x4b3844A29CFA5824F53e2137Edb6dc2b54501BeA,
      0x4a4217d8751a027D853785824eF40522c512A3Fe,
      0x32cB6da260726BB2192c4085B857aFD945A215Cb,
      0xA91D05b7c6e684F43E8Fe0c25B3c4Bb1747A2a9E,
      0xe38aFbE7738b6Ec4280A6bCa1176c1C1A928A19C,
      0xE795F18F2F5DF5a666994e839b98263Dba86C902,
      0x772112C7e5dD4ed663e844e79d77c1569a2E88ce,
      0xF0c48B7F020BB61e6A3500AbC4b4954Bde7A2039,
      0x063105D0E7215B703909a7274FE38393302F3134,
      0xD9d5b3E58fa693B468a20C716793B18A1195380a,
      0xff30Ed09E3AE60D39Bce1727ee3292fD76A6FAce,
      0x8c4AD2DC12AdB9aD115e37EE9aD2e00E343EDf85,
      0x73f5B22312B7B2B3B1Cd179fC62269aB369c8206,
      0x5e04DC8156ce222289d52487dbAdCb01C8c990f9,
      0x564DcB855Eb360826f27D1Eb9c57cbbe6C76F50F,
      0xEC5c90401F95F8c49b1E133E94F09D85b21d96a4,
      0x332253265e36689D9830E57112CD1aaDB1A773f9,
      0x236aF2FFdb611B14e3042A982d13EdA1627d9C96,
      0x54C8C42F07007D43c3049bEF6f10eA68687d43ef,
      0x66225AcC78Be789C57a11C9a18F051C779d678B5,
      0xf4682B9263d1ba9bd9Db09dA125708607d1eDd3a,
      0xc23F2907Bc11848B5d5cEdBB835e915D7b760d99
    ];
    for (uint256 i; i < operators.length; i++) {
      vm.prank(operators[i]);
      _roninGateway.depositFor(receipt);
    }
  }

  function run() public virtual override {
    Simulation__20231003_UpgradeREP002AndREP003_Base.run();

    // -------------- Day #1 --------------------

    address[11] memory governors = [
      0x02201F9bfD2FaCe1b9f9D30d776E77382213Da1A,
      0x4620fb95eaBDaB4Bf681D987e116e0aAef1adEF2,
      0x5832C3219c1dA998e828E1a2406B73dbFC02a70C,
      0x58aBcBCAb52dEE942491700CD0DB67826BBAA8C6,
      0x60c4B72fc62b3e3a74e283aA9Ba20d61dD4d8F1b,
      0x77Ab649Caa7B4b673C9f2cF069900DF48114d79D,
      0x90ead0E8d5F5Bf5658A2e6db04535679Df0f8E43,
      0xbaCB04eA617b3E5EEe0E3f6E8FCB5Ba886B83958,
      0xD5877c63744903a459CCBa94c909CDaAE90575f8,
      0xe258f9996723B910712D6E67ADa4EafC15F7F101,
      0xea172676E4105e92Cc52DBf45fD93b274eC96676
    ];

    // -------------- Day #2 (execute proposal on ronin) --------------------
    _fastForwardToNextDay();
    _wrapUpEpoch();

    vm.warp(block.timestamp + 3 seconds);
    vm.roll(block.number + 1);

    // -- execute proposal

    for (uint256 i = 1; i < governors.length - 2; i++) {
      vm.prank(governors[i]);
      (bool success, bytes memory returnOrRevertData) = address(_roninGovernanceAdmin).call(
        hex"a8a0e32c00000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000007e400000000000000000000000000000000000000000000000000000000653cda8b00000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000320000000000000000000000000000000000000000000000000000000000000056000000000000000000000000000000000000000000000000000000000000013000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000617c5d73662282ea7ffd231e020eca6d2b0d552f000000000000000000000000617c5d73662282ea7ffd231e020eca6d2b0d552f000000000000000000000000545edb750eb8769c868429be9586f5857a768758000000000000000000000000ebfff2b32fa0df9c5c8c5d5aaa7e8b51d5207ba3000000000000000000000000ebfff2b32fa0df9c5c8c5d5aaa7e8b51d5207ba300000000000000000000000098d0230884448b3e2f09a177433d60fb1e19c0900000000000000000000000003fb325b251ee80945d3fc8c7692f5affca1b8bc2000000000000000000000000c768423a2ae2b5024cb58f3d6449a8f5db6d8816000000000000000000000000c768423a2ae2b5024cb58f3d6449a8f5db6d88160000000000000000000000006f45c1f8d84849d497c6c0ac4c3842dc82f498940000000000000000000000000cf8ff40a508bdbc39fbe1bb679dcba64e65c7df0000000000000000000000000cf8ff40a508bdbc39fbe1bb679dcba64e65c7df0000000000000000000000003fb325b251ee80945d3fc8c7692f5affca1b8bc2000000000000000000000000796a163a21e9a659fc9773166e0afdc1eb01aad10000000000000000000000003fb325b251ee80945d3fc8c7692f5affca1b8bc2000000000000000000000000273cda3afe17eb7bcb028b058382a9010ae82b240000000000000000000000000cf8ff40a508bdbc39fbe1bb679dcba64e65c7df0000000000000000000000000000000000000000000000000000000000000011000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000000000000000000000000000000000000000022000000000000000000000000000000000000000000000000000000000000002e000000000000000000000000000000000000000000000000000000000000003a00000000000000000000000000000000000000000000000000000000000000460000000000000000000000000000000000000000000000000000000000000054000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000660000000000000000000000000000000000000000000000000000000000000072000000000000000000000000000000000000000000000000000000000000007e000000000000000000000000000000000000000000000000000000000000008a000000000000000000000000000000000000000000000000000000000000009600000000000000000000000000000000000000000000000000000000000000a200000000000000000000000000000000000000000000000000000000000000ae00000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000000c400000000000000000000000000000000000000000000000000000000000000ce00000000000000000000000000000000000000000000000000000000000000d2000000000000000000000000000000000000000000000000000000000000000844f1ef2860000000000000000000000000c1dee1b435c464b4e94781f94f991cb90e3399d000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000045cd8a76b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000844bb5274a000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000243101cfcb000000000000000000000000a30b2932cd8b8a89e34551cdfa13810af38da576000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000844f1ef2860000000000000000000000008ae952d538e9c25120e9c75fba0718750f81313a000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000045cd8a76b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a44f1ef286000000000000000000000000440baf1c4b008ee4d617a83401f06aa80f5163e90000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000002429b6eca9000000000000000000000000946397dedfd2f79b75a72b322944a21c3240c9c3000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000844bb5274a000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000243101cfcb000000000000000000000000840ebf1ca767cb690029e91856a357a43b85d035000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000243659cfe60000000000000000000000000aada85a2b3c9fb1be158d43e71cdcca6fe85e020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000844f1ef286000000000000000000000000e4ccf400e99cb07eb76d3a169532916069b7dc32000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000045cd8a76b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000844f1ef2860000000000000000000000007ccbb3cd1b19bc1f1d5b7048400d41b1b796abad000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000045cd8a76b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000844bb5274a000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000243c3d84100000000000000000000000000000000000000000000000000000000000000032000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000844f1ef286000000000000000000000000ca9f10769292f26850333264d618c1b5e91f394d000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000045cd8a76b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000844f1ef2860000000000000000000000001477db6bf449b0eb1191a1f4023867ddceadc504000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000045cd8a76b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000844bb5274a000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000243101cfcb0000000000000000000000005fa49e6ca54a9daa8eca4f403adbde5ee075d84a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e44bb5274a00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000084ca21287e0000000000000000000000005fa49e6ca54a9daa8eca4f403adbde5ee075d84a000000000000000000000000273cda3afe17eb7bcb028b058382a9010ae82b24000000000000000000000000796a163a21e9a659fc9773166e0afdc1eb01aad1000000000000000000000000946397dedfd2f79b75a72b322944a21c3240c9c3000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000043b1544550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000644bb5274a000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000043b154455000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000043b1544550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000248f2839700000000000000000000000005fa49e6ca54a9daa8eca4f403adbde5ee075d84a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000000000000000f424000000000000000000000000000000000000000000000000000000000000f424000000000000000000000000000000000000000000000000000000000000f424000000000000000000000000000000000000000000000000000000000000f424000000000000000000000000000000000000000000000000000000000000f424000000000000000000000000000000000000000000000000000000000000f424000000000000000000000000000000000000000000000000000000000000f424000000000000000000000000000000000000000000000000000000000000f424000000000000000000000000000000000000000000000000000000000000f424000000000000000000000000000000000000000000000000000000000000f424000000000000000000000000000000000000000000000000000000000000f424000000000000000000000000000000000000000000000000000000000000f424000000000000000000000000000000000000000000000000000000000000f424000000000000000000000000000000000000000000000000000000000000f424000000000000000000000000000000000000000000000000000000000000f424000000000000000000000000000000000000000000000000000000000000f424000000000000000000000000000000000000000000000000000000000000f4240"
      );

      success.handleRevert(msg.sig, returnOrRevertData);
    }
    // -- done execute proposal

    // Deposit for
    vm.warp(block.timestamp + 3 seconds);
    vm.roll(block.number + 1);
    // _depositFor("after-upgrade-REP2");
    // _dummySwitchNetworks();
    _depositForOnlyOnRonin("after-upgrade-REP2");

    _fastForwardToNextDay();
    vm.warp(block.timestamp + 3 seconds);
    vm.roll(block.number + 1);
    _depositForOnlyOnRonin("after-upgrade-REP2_a");

    _fastForwardToNextDay();
    vm.warp(block.timestamp + 3 seconds);
    vm.roll(block.number + 1);
    _depositForOnlyOnRonin("after-upgrade-REP2_b");

    // -------------- End of Day #2 --------------------

    // - wrap up period
    _fastForwardToNextDay();
    _wrapUpEpoch();

    vm.warp(block.timestamp + 3 seconds);
    vm.roll(block.number + 1);
    _depositForOnlyOnRonin("after-wrapup-Day2"); // share bridge reward here
    // _depositFor("after-DAY2");

    _fastForwardToNextDay();
    vm.warp(block.timestamp + 3 seconds);
    vm.roll(block.number + 1);
    _depositForOnlyOnRonin("after-wrapup-Day2_a");

    // - deposit for

    // -------------- End of Day #3 --------------------
    // - wrap up period
    _fastForwardToNextDay();
    _wrapUpEpoch();

    vm.warp(block.timestamp + 3 seconds);
    vm.roll(block.number + 1);
    _depositForOnlyOnRonin("after-wrapup-Day3"); // share bridge reward here
  }
}