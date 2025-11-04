// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import {Script} from "forge-std/Script.sol";
import {Redemption, Hashes} from "contracts/redemption/Redemption.sol";
import {DeployRedemption} from "script/DeployRedemption.s.sol";
import {Hashes} from "contracts/Hashes.sol";

contract DeployTestRedemption is DeployRedemption {
    function run() public override {
        vm.startBroadcast();
        hashes = new Hashes(0, 0, 1000, "");
        redemptionMultisig = msg.sender;
        for (uint256 i; i < 200; i++) {
            hashes.generate("test");
        }
        redemption = new Redemption(hashes, redemptionMultisig, excludedIds);
        vm.stopBroadcast();
    }
}
