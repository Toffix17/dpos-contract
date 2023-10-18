// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StdStyle } from "forge-std/StdStyle.sol";

import "./20231003_REP002AndREP003_Base.s.sol";
import "./20231003_REP002AndREP003_RON_NonConditional_Wrapup2Periods.s.sol";
import { BridgeRewardDeploy } from "./contracts/BridgeRewardDeploy.s.sol";
import { BridgeSlashDeploy } from "./contracts/BridgeSlashDeploy.s.sol";
import { RoninBridgeManagerDeploy } from "./contracts/RoninBridgeManagerDeploy.s.sol";

import { RoninGatewayV3 } from "@ronin/contracts/ronin/gateway/RoninGatewayV3.sol";
import { BridgeReward } from "@ronin/contracts/ronin/gateway/BridgeReward.sol";
import { BridgeSlash } from "@ronin/contracts/ronin/gateway/BridgeSlash.sol";
import { RoninBridgeManager } from "@ronin/contracts/ronin/gateway/RoninBridgeManager.sol";
import { BridgeTracking } from "@ronin/contracts/ronin/gateway/BridgeTracking.sol";
import { TransparentUpgradeableProxyV2 } from "@ronin/contracts/extensions/TransparentUpgradeableProxyV2.sol";

contract Simulation_20231003_REP002AndREP003_RON_NonConditional_GatewayUpgrade_ActualProposal is
  Simulation__20231003_UpgradeREP002AndREP003_Base
{
  function run() public virtual override trySetUp {
    Simulation__20231003_UpgradeREP002AndREP003_Base.run();

    // -------------- Day #1 --------------------
    vm.prank(0x3200A8eb56767c3760e108Aa27C65bfFF036d8E6);
    address(_roninBridgeManager).call(
      hex"663ac01100000000000000000000000000000000000000000000000000000000653b5c1100000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000001800000000000000000000000000000000000000000000000000000000000000bc0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000020000000000000000000000005a6073071f151fe282aa1267870cde1aff85ff280000000000000000000000005a6073071f151fe282aa1267870cde1aff85ff28000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000980000000000000000000000000000000000000000000000000000000000000090401a5f43f000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000003400000000000000000000000000000000000000000000000000000000000000620000000000000000000000000000000000000000000000000000000000000001600000000000000000000000000000000000000000000000000000000000000640000000000000000000000000000000000000000000000000000000000000064000000000000000000000000000000000000000000000000000000000000006400000000000000000000000000000000000000000000000000000000000000640000000000000000000000000000000000000000000000000000000000000064000000000000000000000000000000000000000000000000000000000000006400000000000000000000000000000000000000000000000000000000000000640000000000000000000000000000000000000000000000000000000000000064000000000000000000000000000000000000000000000000000000000000006400000000000000000000000000000000000000000000000000000000000000640000000000000000000000000000000000000000000000000000000000000064000000000000000000000000000000000000000000000000000000000000006400000000000000000000000000000000000000000000000000000000000000640000000000000000000000000000000000000000000000000000000000000064000000000000000000000000000000000000000000000000000000000000006400000000000000000000000000000000000000000000000000000000000000640000000000000000000000000000000000000000000000000000000000000064000000000000000000000000000000000000000000000000000000000000006400000000000000000000000000000000000000000000000000000000000000640000000000000000000000000000000000000000000000000000000000000064000000000000000000000000000000000000000000000000000000000000006400000000000000000000000000000000000000000000000000000000000000640000000000000000000000000000000000000000000000000000000000000016000000000000000000000000e880802580a1fbdef67ace39d1b21c5b2c74f0590000000000000000000000004b18cebeb9797ea594b5977109cc07b21c37e8c3000000000000000000000000a441f1399c8c023798586fbbbcf35f27279638a100000000000000000000000072a69b04b59c36fced19ac54209bef878e84fcbf000000000000000000000000e258f9996723b910712d6e67ada4eafc15f7f101000000000000000000000000020dd9a5e318695a61dda88db7ad077ec306e3e90000000000000000000000002d593a0087029501ee419b9415dec3fac195fe4a0000000000000000000000009b0612e43855ef9a7c329ee89653ba45273b550e00000000000000000000000047cfcb64f8ea44d6ea7fab32f13efa2f8e65eec1000000000000000000000000ad23e87306aa3c7b95ee760e86f40f3021e5fa18000000000000000000000000bacb04ea617b3e5eee0e3f6e8fcb5ba886b8395800000000000000000000000077ab649caa7b4b673c9f2cf069900df48114d79d0000000000000000000000000dca20728c8bb7173d3452559f40e95c609157990000000000000000000000000d48adbdc523681c0dee736dbdc4497e02bec210000000000000000000000000ea172676e4105e92cc52dbf45fd93b274ec96676000000000000000000000000ed448901cc62be10c5525ba19645ddca1fd9da1d000000000000000000000000332253265e36689d9830e57112cd1aadb1a773f900000000000000000000000058abcbcab52dee942491700cd0db67826bbaa8c60000000000000000000000004620fb95eabdab4bf681d987e116e0aaef1adef2000000000000000000000000c092fa0c772b3c850e676c57d8737bb39084b9ac00000000000000000000000060c4b72fc62b3e3a74e283aa9ba20d61dd4d8f1b000000000000000000000000ed3805fb65ff51a99fef4676bdbc97abeca93d1100000000000000000000000000000000000000000000000000000000000000160000000000000000000000004b3844a29cfa5824f53e2137edb6dc2b54501bea0000000000000000000000004a4217d8751a027d853785824ef40522c512a3fe00000000000000000000000032cb6da260726bb2192c4085b857afd945a215cb000000000000000000000000a91d05b7c6e684f43e8fe0c25b3c4bb1747a2a9e000000000000000000000000e38afbe7738b6ec4280a6bca1176c1c1a928a19c000000000000000000000000e795f18f2f5df5a666994e839b98263dba86c902000000000000000000000000772112c7e5dd4ed663e844e79d77c1569a2e88ce000000000000000000000000f0c48b7f020bb61e6a3500abc4b4954bde7a2039000000000000000000000000063105d0e7215b703909a7274fe38393302f3134000000000000000000000000d9d5b3e58fa693b468a20c716793b18a1195380a000000000000000000000000ff30ed09e3ae60d39bce1727ee3292fd76a6face0000000000000000000000008c4ad2dc12adb9ad115e37ee9ad2e00e343edf8500000000000000000000000073f5b22312b7b2b3b1cd179fc62269ab369c82060000000000000000000000005e04dc8156ce222289d52487dbadcb01c8c990f9000000000000000000000000564dcb855eb360826f27d1eb9c57cbbe6c76f50f000000000000000000000000ec5c90401f95f8c49b1e133e94f09d85b21d96a4000000000000000000000000332253265e36689d9830e57112cd1aadb1a7dead000000000000000000000000236af2ffdb611b14e3042a982d13eda1627d9c9600000000000000000000000054c8c42f07007d43c3049bef6f10ea68687d43ef00000000000000000000000066225acc78be789c57a11c9a18f051c779d678b5000000000000000000000000f4682b9263d1ba9bd9db09da125708607d1edd3a000000000000000000000000c23f2907bc11848b5d5cedbb835e915d7b760d99000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000064e9c034980000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000100000000000000000000000032015e8b982c61bc8a593816fdbf03a603eec82300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000f424000000000000000000000000000000000000000000000000000000000000f4240"
    );
  }
}
