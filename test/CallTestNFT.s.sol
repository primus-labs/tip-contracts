
// script/Deploy.s.sol
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "./PrimusTestNFT.sol";
import "forge-std/Test.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        PrimusTestNFT nftToken = PrimusTestNFT(address(0xDF53423C5475168caAD96aDf047AC34449cd5E17));
        for (uint i = 51; i < 61; i++) {
            nftToken.safeMint(address(0x2B99d37183a3415C429901800fFBec7de5eE897e), "https://storage.googleapis.com/primus-online/others/primustestnft.json");
        }
        console.log("nft owner:", nftToken.ownerOf(60));

        vm.stopBroadcast();
    }
}

