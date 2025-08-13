// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

interface IPlatformGovernance {
    function isAdmin(address account) external view returns (bool);
}

abstract contract UpgradeableAccessControl is Initializable, UUPSUpgradeable {
    IPlatformGovernance public platformGovernance;
    address public platformGovernanceAddress;

    event UpgradeAuthorized(address implementation, address user);

    modifier onlyAdmin() {
        require(platformGovernance.isAdmin(msg.sender), "Not admin");
        _;
    }

    modifier onlyGovernance() {
        require(platformGovernanceAddress == msg.sender, "Not governance");
        _;
    }

    function __UpgradeableAccessControl_init(
        address _platformGovernance
    ) internal onlyInitializing {
        platformGovernance = IPlatformGovernance(_platformGovernance);
        platformGovernanceAddress = _platformGovernance;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyAdmin {
        require(newImplementation != address(0), "Zero implementation");

        emit UpgradeAuthorized(newImplementation, msg.sender);
    }

    uint256[50] private __gap;
}
