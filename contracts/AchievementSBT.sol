// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "./UpgradeableAccessControl.sol";

/// @title AchievementSBT
/// @notice Soul-bound badges earned automatically for fights & tournaments
contract AchievementSBT is
    ERC721URIStorageUpgradeable,
    UpgradeableAccessControl
{
    /* ---------- BADGE TYPES ---------- */
    enum BadgeType {
        SELF_MADE,
        NEOPHYTE,
        ENTHUSIAST,
        ADEPT,
        FANATIC,
        NOVICE,
        AMATEUR,
        FIGHTER,
        VETERAN,
        INITIATION
    }

    /* ---------- STORAGE ---------- */
    uint256 private _tokenIdCounter;
    address public tournamentAddress; // адрес единственного вызывающего

    mapping(uint256 => BadgeType) public badgeOf;
    mapping(address => uint256[]) public userAchievements;
    mapping(address => mapping(BadgeType => bool)) public _hasBadge;

    /* ---------- EVENTS ---------- */
    event AchievementIssued(
        address indexed user,
        uint256 indexed tokenId,
        BadgeType indexed badge
    );

    /* ---------- CONSTRUCTOR ---------- */
    function initialize(
        address governance,
        address tournament
    ) public initializer {
        __ERC721_init("HEMA Achievements", "HACH");
        __UpgradeableAccessControl_init(governance);
        tournamentAddress = tournament;
        _tokenIdCounter = 0;
    }

    modifier onlyTournament() {
        require(msg.sender == tournamentAddress, "Only Tournament");
        _;
    }

    function issueBadge(
        address user,
        BadgeType badge,
        string calldata uri
    ) external onlyTournament {
        _mint(user, _tokenIdCounter);
        _setTokenURI(_tokenIdCounter, uri);
        badgeOf[_tokenIdCounter] = badge;
        userAchievements[user].push(_tokenIdCounter);
        _hasBadge[user][badge] = true;

        emit AchievementIssued(user, _tokenIdCounter, badge);
        _tokenIdCounter++;
    }

    /// @dev проверка, есть ли у пользователя конкретный badge
    function hasBadge(
        address user,
        BadgeType badge
    ) internal view returns (bool) {
        return _hasBadge[user][badge];
    }

    /* ---------- VIEW ---------- */
    function userAchievementsList(
        address user
    ) external view returns (uint256[] memory) {
        return userAchievements[user];
    }

    /* ---------- BLOCK TRANSFER ---------- */
    function transferFrom(
        address,
        address,
        uint256
    ) public pure override(ERC721Upgradeable, IERC721) {
        revert("AchievementSBT: transfer disabled");
    }
}
