// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./Fencer.sol";
import "./Tournament.sol";

contract PlatformGovernance is Context, Initializable, UUPSUpgradeable {
    enum ProposalType {
        ADD_ADMIN,
        REMOVE_ADMIN,
        ADD_WEAPON,
        REMOVE_WEAPON,
        ADD_NOMINATION,
        REMOVE_NOMINATION
    }

    enum ProposalCategory {
        ADMIN,
        TYPE
    }

    uint256 public constant QUORUM = 51; // 51%
    uint256 public constant VOTE_DURATION = 3 days;
    Fencer public fencer;
    Tournament public tournament;

    address[] public admins;
    mapping(address => bool) public isAdmin;
    mapping(address => mapping(ProposalCategory => mapping(uint256 => bool)))
        public voted;

    struct BaseProposal {
        ProposalType pType;
        address proponent;
        uint256 votesYes;
        uint256 votesNo;
        uint256 deadline;
        bool executed;
    }

    struct ProposalAdmin {
        address candidate;
        BaseProposal base;
    }

    struct ProposalAddType {
        string title;
        uint8 weaponTypeId;
        uint8 nominationId;
        BaseProposal base;
    }

    ProposalAdmin[] public proposalsAdmin;
    ProposalAddType[] public proposalsTypes;
    address public weaponsContract;
    address public tournamentContract;

    event UpgradeAuthorized(address implementation, address user);
    event ProposalAdminCreated(
        uint256 indexed id,
        ProposalType pType,
        address candidate
    );
    event Voted(
        ProposalCategory category,
        uint256 indexed id,
        address voter,
        bool support
    );
    event AdminUpdated(address indexed admin, bool added);

    modifier onlyAdmin() {
        require(isAdmin[_msgSender()], "Not admin");
        _;
    }

    function proposalsConditions(BaseProposal memory base) internal view {
        require(base.proponent == _msgSender(), "Not proponent");
        require(block.timestamp >= base.deadline, "Vote active");
        require(!base.executed, "Already executed");
        require(_quorumReached(base), "Quorum not reached");
        require(base.votesYes > base.votesNo, "Majority not reached");
    }

    function initialize(address[] memory initialAdmins) public initializer {
        for (uint256 i = 0; i < initialAdmins.length; i++) {
            _addAdmin(initialAdmins[i]);
        }
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyAdmin {
        require(newImplementation != address(0), "Zero implementation");

        emit UpgradeAuthorized(newImplementation, msg.sender);
    }

    function initAddress(
        address fencerAddress,
        address tournamentAddress
    ) external onlyAdmin {
        fencer = Fencer(fencerAddress);
        tournament = Tournament(tournamentAddress);
    }

    function createProposalAdmin(
        address _candidate,
        ProposalType _pType
    ) external returns (uint256 id) {
        id = proposalsAdmin.length;
        proposalsAdmin.push(
            ProposalAdmin({
                candidate: _candidate,
                base: BaseProposal({
                    pType: _pType,
                    proponent: _msgSender(),
                    votesYes: 0,
                    votesNo: 0,
                    deadline: block.timestamp + VOTE_DURATION,
                    executed: false
                })
            })
        );
        emit ProposalAdminCreated(id, _pType, _candidate);
    }

    function createProposalTypes(
        string calldata _title,
        uint8 _weaponTypeId,
        uint8 _nominationId,
        ProposalType _pType
    ) external onlyAdmin returns (uint256 id) {
        proposalsTypes.push(
            ProposalAddType({
                title: _title,
                weaponTypeId: _weaponTypeId,
                nominationId: _nominationId,
                base: BaseProposal({
                    pType: _pType,
                    proponent: _msgSender(),
                    votesYes: 0,
                    votesNo: 0,
                    deadline: block.timestamp + VOTE_DURATION,
                    executed: false
                })
            })
        );
    }

    function vote(
        ProposalCategory category,
        uint256 id,
        bool support
    ) external {
        BaseProposal storage base = category == ProposalCategory.ADMIN
            ? proposalsAdmin[id].base
            : proposalsTypes[id].base;
        require(block.timestamp < base.deadline, "Vote ended");
        require(!voted[_msgSender()][category][id], "Already voted");

        voted[_msgSender()][category][id] = true;
        support ? base.votesYes++ : base.votesNo++;

        emit Voted(category, id, _msgSender(), support);
    }

    function executeProposalAdmin(uint256 id) external {
        ProposalAdmin storage p = proposalsAdmin[id];
        proposalsConditions(p.base);

        p.base.executed = true;

        if (p.base.pType == ProposalType.ADD_ADMIN) {
            _addAdmin(p.candidate);
        } else if (p.base.pType == ProposalType.REMOVE_ADMIN) {
            _removeAdmin(p.candidate);
        }
    }

    function executeProposalType(uint256 id) external {
        ProposalAddType storage p = proposalsTypes[id];
        proposalsConditions(p.base);

        p.base.executed = true;

        if (p.base.pType == ProposalType.ADD_WEAPON) {
            tournament.addWeaponType(p.title);
        } else if (p.base.pType == ProposalType.REMOVE_WEAPON) {
            tournament.removeWeaponType(p.weaponTypeId);
        } else if (p.base.pType == ProposalType.ADD_NOMINATION) {
            tournament.addNomination(p.weaponTypeId, p.title);
        } else if (p.base.pType == ProposalType.REMOVE_NOMINATION) {
            tournament.removeNomination(p.weaponTypeId, p.nominationId);
        }
    }

    function _addAdmin(address admin) internal {
        require(!isAdmin[admin], "Already admin");
        isAdmin[admin] = true;
        admins.push(admin);
        emit AdminUpdated(admin, true);
    }

    function _removeAdmin(address admin) internal {
        require(isAdmin[admin], "Not admin");
        isAdmin[admin] = false;
        for (uint256 i = 0; i < admins.length; i++) {
            if (admins[i] == admin) {
                admins[i] = admins[admins.length - 1];
                admins.pop();
                break;
            }
        }
        emit AdminUpdated(admin, false);
    }

    function _quorumReached(
        BaseProposal memory p
    ) internal view returns (bool) {
        uint256 totalVotes = p.votesYes + p.votesNo;
        return (totalVotes * 100) >= (fencer.getAllUsers().length * QUORUM);
    }
}
