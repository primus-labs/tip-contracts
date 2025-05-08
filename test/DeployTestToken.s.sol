
// script/Deploy.s.sol
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import "./PrimusTestToken.sol";
import "forge-std/Test.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        PrimusTestToken testToken = new PrimusTestToken(100000000 * 1 ether);

        console.log("token Address: ", address(testToken));
        console.log("nft owner:", testToken.balanceOf(deployerAddress));

        vm.stopBroadcast();
    }
}

