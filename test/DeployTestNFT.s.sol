
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
        address deployerAddress = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        PrimusTestNFT nftToken = new PrimusTestNFT(deployerAddress);
        for (uint i = 0; i < 1; i++) {
            nftToken.safeMint(address(0x810b7bacEfD5ba495bB688bbFD2501C904036AB7), "uri");
        }
        console.log("nftToken Address: ", address(nftToken));
        console.log("nft owner:", nftToken.ownerOf(0));

        vm.stopBroadcast();
    }
}

