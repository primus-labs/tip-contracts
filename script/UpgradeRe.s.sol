// script/Upgrade.s.sol
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {PrimusRedEnvelope} from "../src/PrimusRedEnvelope.sol";
import "forge-std/Test.sol";

// script/Upgrade.s.sol
import {ProxyAdmin} from  "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy, ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract UpgradeScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy the new logic contract
        PrimusRedEnvelope newLogic = new PrimusRedEnvelope();

        // pharos testnet
        address proxyAdminAddr = address(0x8e1D6B278D4304D7cb5FEfe9D4C8117DAf99F822);
        address proxyAddr = address(0x673D74d95A35B26804475066d9cD1DA3947f4eC3);

        // bsc testnet
        // address proxyAdminAddr = address(0x08f4E5559807A7360156Dd9E0c2587B86dDB266E);
        // address proxyAddr = address(0xC75901570dB65070caDEBB74d6702E299Ac8e019);

        // monad testnet
        // address proxyAdminAddr = address(0xe830d0A93a13e2a893c708A3D63056c310fA8B2a);
        // address proxyAddr = address(0x5508fC45d930B5dE36647Dbbe5B9414e43C4F614);

        // base sepolia
        // address proxyAdminAddr = address(0x832F1f7110dfa99C8EF1B08810b088332393Dd42);
        // address proxyAddr = address(0xA33Ed35460C3d06094693956B2d7Cd1a9e7A39a8);

        // bsc mainnet
        // address proxyAdminAddr = address(0x4C5a064529946e4e8a22e80BaAE865deba9D876b);
        // address proxyAddr = address(0x083693C148e30b3A231D325366E76b38293FCa10);

        // base mainnet
        // address proxyAdminAddr = address(0x5373eDbf1eE8F725c2848Ee7A6CEe763c12faC18);
        // address proxyAddr = address(0x50bd377EB8D4236Bb587AB3FB1eeafd888AEeC58);


        // 3. Call the upgrade method of ProxyAdmin
        ProxyAdmin proxyAdmin = ProxyAdmin(proxyAdminAddr);
        proxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(proxyAddr), address(newLogic), "");

        console.log("Upgraded Proxy to New Logic Address: ", address(newLogic));

        vm.stopBroadcast();
    }
}