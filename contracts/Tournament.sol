// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./Fencer.sol"; // рейтинг хранится здесь
import "./AchievementSBT.sol";
import "./UpgradeableAccessControl.sol";

/// @title Tournament
/// @dev Полный турнир-контракт с номинациями, судьями, Elo-рейтингом
contract Tournament is UpgradeableAccessControl {
    /* ------------------ CONSTANTS ------------------ */
    uint256 private constant G_TAU = 5e17; // τ = 0.5
    uint256 private constant G_EPS = 1;

    uint256 private constant NEOPHYTE_THRESHOLD = 5;
    uint256 private constant ENTHUSIAST_THRESHOLD = 25;
    uint256 private constant ADEPT_THRESHOLD = 50;
    uint256 private constant FANATIC_THRESHOLD = 75;

    uint256 private constant NOVICE_TOURNAMENT_THRESHOLD = 5;
    uint256 private constant AMATEUR_TOURNAMENT_THRESHOLD = 15;
    uint256 private constant FIGHTER_TOURNAMENT_THRESHOLD = 15;
    uint256 private constant VETERAN_TOURNAMENT_THRESHOLD = 20;

    uint256 public tournamentCount;

    Fencer public fencer;
    AchievementSBT public achievementSBT;
    /* ------------------ STRUCTS ------------------ */
    struct Nomination {
        uint8 nameId;
        uint8 max;
        address[] participants;
        address[3] winners;
        string badgeURI;
        uint8 weaponId;
        Fencer.Gender gender;
    }

    struct TournamentInfo {
        address owner;
        string name;
        string metadataCID;
        uint256 cityId;
        uint256 countryId;
        uint256 date;
        uint16 startTime;
        Nomination[] nominations;
        address[] judges;
    }

    struct Pairs {
        address fighter1;
        address fighter2;
    }

    struct Fight {
        uint8 nominationId;
        address fighter1;
        address fighter2;
        address winner;
        bool confirmed;
    }

    struct JudgeLog {
        address judge;
        string action;
        uint256 timestamp;
    }

    string[] public badgesURI;

    /* ------------------ STORAGE ------------------ */
    mapping(uint256 => TournamentInfo) public tournaments;
    mapping(address => uint256[]) private ownerTournaments;
    mapping(uint256 => mapping(address => bool)) public hasJudges;
    mapping(uint256 => mapping(uint256 => Fight)) public fights;
    mapping(uint256 => mapping(uint256 => Pairs[]))
        public nominationParticipants; // tournamentId => nominationId => pairs[]
    mapping(uint256 => string[]) public nominationsNames;
    mapping(uint256 => JudgeLog[]) public judgeLogs;
    string[] public weaponTypes;
    /* ------------------ EVENTS ------------------ */
    event TournamentCreated(
        string name,
        string metadataCID,
        uint256 indexed cityId,
        uint256 indexed countryId,
        uint256 date,
        uint256 startTime,
        uint256 tournamentId
    );
    event JudgeAdded(address indexed judge, uint256 tournamentId);
    event JudgeRemoved(address indexed judge, uint256 tournamentId);
    event JudgeActionLogged(
        address indexed judge,
        string action,
        uint256 tournamentId
    );
    event FightCreated(
        uint256 indexed nominationId,
        uint256 indexed fightId,
        address indexed fighter1,
        address fighter2
    );
    event FightConfirmed(
        uint256 indexed nominationId,
        uint256 indexed fightId,
        address indexed winner
    );

    event FightRecorded(
        uint8 weaponId,
        uint8 indexed nominationId,
        address indexed fighter1,
        address indexed fighter2,
        uint256 win1,
        uint256 win2
    );

    /* ------------------ MODIFIERS ------------------ */
    modifier onlyOwner(uint256 tournamentId) {
        require(msg.sender == tournaments[tournamentId].owner, "Only judge");
        _;
    }

    modifier onlyOrganizers(uint256 tournamentId) {
        require(
            msg.sender == tournaments[tournamentId].owner ||
                hasJudges[tournamentId][msg.sender],
            "Only organizers"
        );
        _;
    }

    modifier checkNomination(uint256 tournamentId, uint8 nominationId) {
        require(
            nominationId < tournaments[tournamentId].nominations.length,
            "Bad nomination"
        );
        _;
    }

    /* ------------------ CONSTRUCTOR ------------------ */
    function initialize(
        address _platformGovernance,
        address _fencer
    ) public initializer {
        __UpgradeableAccessControl_init(_platformGovernance);
        fencer = Fencer(_fencer);

        tournamentCount = 0;

        badgesURI = [
            "",
            "Neophyte",
            "Enthusiast",
            "Adept",
            "Fanatic",
            "Novice",
            "Amateur",
            "Fighter",
            "Veteran",
            "Initiation"
        ]; // badges uri

        weaponTypes = [
            "Longsword",
            "Sabre",
            "Rapier",
            "Rapier & Dagger",
            "Dussak",
            "Spear",
            "Sword & Buckler",
            "Sidesword"
        ];

        nominationsNames[0] = [
            "Longsword",
            "Longsword - Advanced",
            "Longsword - Beginner",
            "Longsword - Continuous",
            "Longsword - Kids",
            "Longsword - Women"
        ];
        nominationsNames[1] = [
            "Saber",
            "Saber - Advanced",
            "Saber - Kids",
            "Saber - kids (boys)",
            "Saber - kids (girls)",
            "Saber - Women"
        ];
        nominationsNames[2] = [
            "Rapier",
            "Rapier - Advanced",
            "Rapier - Kids",
            "Rapier - Women"
        ];
        nominationsNames[3] = [
            "Rapier & Dagger",
            "Rapier & Dagger - Advanced",
            "Rapier & Dagger - Women"
        ];
        nominationsNames[4] = ["Dussak", "Dussak - Women"];
        nominationsNames[5] = ["Spear", "Spear & Shield"];
        nominationsNames[6] = ["Sword & Buckler", "Sword & Buckler - Women"];
        nominationsNames[7] = ["Sidesword"];
    }

    function setAchievementSBT(address _achievement) external onlyAdmin {
        require(address(achievementSBT) == address(0), "Already set");
        achievementSBT = AchievementSBT(_achievement);
    }

    function createTournament(
        string memory _name,
        string memory _metadataCID,
        uint256 _cityId,
        uint256 _countryId,
        uint256 _date,
        uint16 _startTime,
        bytes calldata _nominationsPacked
    ) external {
        tournaments[tournamentCount].owner = msg.sender;
        tournaments[tournamentCount].name = _name;
        tournaments[tournamentCount].metadataCID = _metadataCID;
        tournaments[tournamentCount].cityId = _cityId;
        tournaments[tournamentCount].countryId = _countryId;
        tournaments[tournamentCount].date = _date;
        tournaments[tournamentCount].startTime = _startTime;
        tournaments[tournamentCount].nominations = abi.decode(
            _nominationsPacked,
            (Nomination[])
        );

        emit TournamentCreated(
            _name,
            _metadataCID,
            _cityId,
            _countryId,
            _date,
            _startTime,
            tournamentCount
        );
        ownerTournaments[msg.sender].push(tournamentCount);
        tournamentCount++;
    }

    function finishTournament(
        uint256 tournamentId,
        uint8 nominationId,
        address winner1,
        address winner2,
        address winner3
    )
        external
        onlyOwner(tournamentId)
        checkNomination(tournamentId, nominationId)
    {
        address[3] memory winners = [winner1, winner2, winner3];

        tournaments[tournamentId].nominations[nominationId].winners = winners;
        string memory badgeURI = tournaments[tournamentId]
            .nominations[nominationId]
            .badgeURI;

        if (bytes(badgeURI).length > 0) {
            for (uint i = 0; i < winners.length; i++) {
                _issueTournamentBadges(
                    tournaments[tournamentId]
                        .nominations[nominationId]
                        .weaponId,
                    nominationId,
                    winners[i]
                );
            }
        }
        achievementSBT.issueBadge(
            winner1,
            AchievementSBT.BadgeType.SELF_MADE,
            badgeURI
        );
    }

    /* ------------------ JUDGE MANAGEMENT ------------------ */
    function addJudge(
        address judge,
        uint256 tournamentId
    ) external onlyOwner(tournamentId) {
        hasJudges[tournamentId][judge] = true;
        tournaments[tournamentId].judges.push(judge);
        emit JudgeAdded(judge, tournamentId);
    }

    function removeJudge(
        address judge,
        uint256 tournamentId
    ) external onlyOwner(tournamentId) {
        hasJudges[tournamentId][judge] = false;
        emit JudgeRemoved(judge, tournamentId);
    }

    /* ------------------ PARTICIPANT REGISTRATION ------------------ */
    function registerParticipant(
        uint8 nominationId,
        uint256 tournamentId
    ) external checkNomination(tournamentId, nominationId) {
        Nomination storage nom = tournaments[tournamentId].nominations[
            nominationId
        ];
        bool alreadyRegistered = false;
        for (uint i = 0; i < nom.participants.length; i++) {
            if (nom.participants[i] == msg.sender) {
                alreadyRegistered = true;
                break;
            }
        }
        require(!alreadyRegistered, "Already registered");
        require(nom.participants.length < nom.max, "Full");
        tournaments[tournamentId].nominations[nominationId].participants.push(
            msg.sender
        );
    }

    /* ------------------ CONFIRM RESULT & ELO ------------------ */
    function confirmFight(
        uint8 weaponId,
        uint8 nominationId,
        address fighter1,
        address fighter2,
        uint256 win1,
        uint256 win2,
        uint256 tournamentId
    )
        external
        onlyOrganizers(tournamentId)
        checkNomination(tournamentId, nominationId)
    {
        require(weaponId < weaponTypes.length, "Bad weapon");

        (uint256 rating1, uint256 rd1, uint256 vol1) = fencer.ratings(
            weaponId,
            nominationId,
            fighter1
        );
        (uint256 rating2, uint256 rd2, uint256 vol2) = fencer.ratings(
            weaponId,
            nominationId,
            fighter2
        );

        (uint256 newR1, uint256 newRd1, uint256 newVol1) = _glickoUpdate(
            rating1,
            rd1,
            vol1,
            win1,
            rating2,
            rd2
        );
        (uint256 newR2, uint256 newRd2, uint256 newVol2) = _glickoUpdate(
            rating2,
            rd2,
            vol2,
            win2,
            rating1,
            rd1
        );

        fencer.updateGlicko(
            weaponId,
            nominationId,
            fighter1,
            newR1,
            newRd1,
            newVol1
        );
        fencer.updateGlicko(
            weaponId,
            nominationId,
            fighter2,
            newR2,
            newRd2,
            newVol2
        );

        _issueFightBadges(weaponId, nominationId, fighter1, win1 >= win2);
        _issueFightBadges(weaponId, nominationId, fighter2, win1 <= win2);

        emit FightRecorded(
            weaponId,
            nominationId,
            fighter1,
            fighter2,
            win1,
            win2
        );
        _logJudgeAction("Fight confirmed", tournamentId);
    }

    /* ------------------ INTERNAL HELPERS ------------------ */
    function _glickoUpdate(
        uint256 r,
        uint256 rd,
        uint256 vol,
        uint256 score,
        uint256 rOpp,
        uint256 rdOpp
    ) internal pure returns (uint256, uint256, uint256) {
        // 🔒 Защита от деления на ноль
        if (rd == 0) rd = 1;
        if (rdOpp == 0) rdOpp = 1;
        if (vol == 0) vol = 1;

        /* упрощённая реализация на 18-знаках */
        uint256 g = 1e18 / (1e18 + (3 * vol * rdOpp * rdOpp) / 1e36);

        // e = 1 / (1 + 10^((rOpp - r)/400))
        int256 exp = int256(rOpp - r);
        uint256 power = 10 ** (uint256((exp * 1e18) / (400 * 1e18))); // ⚠️ Опасно при rOpp < r!
        uint256 e = 1e18 / (1e18 + power);

        // ⚠️ Проверка: знаменатель не должен быть 0
        uint256 gSquared = (g * g) / 1e18;
        uint256 eTerm = (e * (1e18 - e)) / 1e18;
        uint256 denominatorV = (gSquared * eTerm) / 1e18;
        if (denominatorV == 0) {
            denominatorV = 1; // Защита
        }
        uint256 v = 1e36 / denominatorV;

        // ⚠️ Проверка перед делением
        uint256 term1 = (rd < 1e18) ? 1e36 : 1e18 / rd; // Избегаем 1/0
        uint256 term2 = (v < 1e18) ? 1e36 : 1e18 / v;
        uint256 sum = term1 + term2;
        if (sum == 0) sum = 1;

        uint256 newRd = 1e36 / sum;
        uint256 delta = (g * (score * 1e18 - e)) / 1e18;
        uint256 newRating = r + (v * delta) / 1e36;
        uint256 newVol = vol; // τ-шаг упрощён

        return (newRating, newRd, newVol);
    }

    function _issueFightBadges(
        uint8 weaponId,
        uint8 nominationId,
        address user,
        bool win
    ) internal {
        uint256 f = fencer.fights(weaponId, nominationId, user);
        fencer.incFight(weaponId, nominationId, user, win);
        AchievementSBT.BadgeType badge;
        if (f == NEOPHYTE_THRESHOLD) badge = AchievementSBT.BadgeType.NEOPHYTE;
        else if (f == ENTHUSIAST_THRESHOLD)
            badge = AchievementSBT.BadgeType.ENTHUSIAST;
        else if (f == ADEPT_THRESHOLD) badge = AchievementSBT.BadgeType.ADEPT;
        else if (f == FANATIC_THRESHOLD)
            badge = AchievementSBT.BadgeType.FANATIC;
        else return;
        achievementSBT.issueBadge(user, badge, badgesURI[uint256(badge)]);
    }

    function _issueTournamentBadges(
        uint8 weaponId,
        uint8 nominationId,
        address user
    ) internal {
        uint256 t = fencer.tournamentsWins(weaponId, nominationId, user);
        AchievementSBT.BadgeType badge;
        if (t == 0) {
            achievementSBT.issueBadge(
                user,
                AchievementSBT.BadgeType.INITIATION,
                badgesURI[uint256(AchievementSBT.BadgeType.INITIATION)]
            );
        }

        fencer.incTournament(weaponId, nominationId, user);

        if (t == NOVICE_TOURNAMENT_THRESHOLD)
            badge = AchievementSBT.BadgeType.NOVICE;
        else if (t == AMATEUR_TOURNAMENT_THRESHOLD)
            badge = AchievementSBT.BadgeType.AMATEUR;
        else if (t == FIGHTER_TOURNAMENT_THRESHOLD)
            badge = AchievementSBT.BadgeType.FIGHTER;
        else if (t == VETERAN_TOURNAMENT_THRESHOLD)
            badge = AchievementSBT.BadgeType.VETERAN;
        else return;

        achievementSBT.issueBadge(user, badge, badgesURI[uint256(badge)]);
    }

    function _logJudgeAction(
        string memory action,
        uint256 tournamentId
    ) internal {
        judgeLogs[tournamentId].push(
            JudgeLog(msg.sender, action, block.timestamp)
        );
        emit JudgeActionLogged(msg.sender, action, tournamentId);
    }

    /* ------------------ VIEW HELPERS ------------------ */
    function addWeaponType(string calldata _type) external onlyGovernance {
        weaponTypes.push(_type);
    }

    function removeWeaponType(uint8 index) external onlyGovernance {
        require(index < weaponTypes.length, "Index out of bounds");

        if (index != weaponTypes.length - 1) {
            weaponTypes[index] = weaponTypes[weaponTypes.length - 1];
        }

        weaponTypes.pop();
    }

    function getWeaponTypes() external view returns (string[] memory) {
        return weaponTypes;
    }

    function addNomination(
        uint8 weaponTypeId,
        string calldata name
    ) external onlyGovernance {
        nominationsNames[weaponTypeId].push(name);
    }

    function removeNomination(
        uint8 weaponTypeId,
        uint8 index
    ) external onlyGovernance {
        require(weaponTypeId < weaponTypes.length, "Invalid weapon type ID");
        string[] storage nominations = nominationsNames[weaponTypeId];
        require(index < nominations.length, "Index out of bounds");

        if (index != nominations.length - 1) {
            nominations[index] = nominations[nominations.length - 1];
        }

        nominations.pop();
    }

    function getNomination(
        uint8 id,
        uint256 tournamentId
    )
        external
        view
        returns (uint8, string memory, uint8, address[] memory, Fencer.Gender)
    {
        Nomination memory n = tournaments[tournamentId].nominations[id];
        string memory name = nominationsNames[n.weaponId][n.nameId];
        return (n.nameId, name, n.max, n.participants, n.gender);
    }

    function getNominations(
        uint8[] calldata weaponIds
    ) external view returns (string[][] memory names) {
        names = new string[][](weaponIds.length);
        for (uint8 i = 0; i < weaponIds.length; i++) {
            names[weaponIds[i]] = nominationsNames[weaponIds[i]];
        }
        return names;
    }

    function getParticipants(
        uint8 nominationId,
        uint256 tournamentId
    ) external view returns (Pairs[] memory) {
        return nominationParticipants[tournamentId][nominationId];
    }

    function getTournament(
        uint256 tournamentId
    ) external view returns (TournamentInfo memory) {
        return tournaments[tournamentId];
    }

    function getTournaments()
        external
        view
        returns (TournamentInfo[] memory result, uint256[] memory ids)
    {
        ids = ownerTournaments[msg.sender];
        result = new TournamentInfo[](ids.length);
        for (uint256 i = 0; i < ids.length; i++) {
            if (tournaments[i].owner == msg.sender) {
                result[i] = tournaments[ids[i]];
            }
        }
        return (result, ids);
    }
}
