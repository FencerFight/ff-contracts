// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./UpgradeableAccessControl.sol";

contract Fencer is UpgradeableAccessControl {
    function initialize(address _platformGovernance) public initializer {
        __UpgradeableAccessControl_init(_platformGovernance);
    }

    enum Gender {
        MALE,
        FEMALE
    }
    /* ---------- STRUCT ---------- */
    struct User {
        string name;
        Gender gender;
        uint256 cityId;
        uint256 countryId;
        uint256 clubId;
    }

    struct Rating {
        uint256 rating; // µ  (1500)
        uint256 rd; // φ  (300)
        uint256 vol; // σ  (0.06 = 60000 в 18-знаках)
    }

    /* ---------- STORAGE ---------- */
    mapping(address => User) public users;
    address[] public allUsers;
    /* weapon => nomination => user => Rating */
    mapping(uint256 => mapping(uint256 => mapping(address => Rating)))
        public ratings;
    /* weapon => nomination => user => counters */
    mapping(uint256 => mapping(uint256 => mapping(address => uint256)))
        public fights;
    mapping(uint256 => mapping(uint256 => mapping(address => uint256)))
        public tournamentsWins;
    mapping(uint256 => mapping(uint256 => mapping(address => uint256)))
        public wins;

    modifier onlyUser(address addr) {
        require(msg.sender == addr, "Not a user");
        _;
    }

    /* списки городов / стран / клубов  */
    string[] public cities;
    string[] public countries;
    string[] public clubs;

    /* ---------- EVENTS ---------- */
    event UserUpdated(
        address indexed user,
        string name,
        Gender gender,
        uint256 cityId,
        uint256 countryId,
        uint256 clubId
    );

    event RatingUpdated(
        uint256 indexed weaponId,
        address indexed user,
        uint256 rating,
        uint256 rd,
        uint256 vol
    );

    /* ---------- MUTATORS ---------- */
    function addUser(
        string calldata _name,
        uint256 _cityId,
        uint256 _countryId,
        uint256 _clubId,
        Gender _gender
    ) external {
        require(
            bytes(users[msg.sender].name).length == 0,
            "User already registered"
        );
        users[msg.sender] = User(_name, _gender, _cityId, _countryId, _clubId);
        allUsers.push(msg.sender);
        emit UserUpdated(
            msg.sender,
            _name,
            _gender,
            _cityId,
            _countryId,
            _clubId
        );
    }

    function addWeaponRating(uint8 weaponId, uint8 nominationId) external {
        // require(weaponId < weaponTypes.length, "Invalid weaponId");
        uint256 initialRating = 1500;
        uint256 initialRd = 300;
        uint256 initialVol = 6e16; // 0.06 с 18 знаками

        ratings[weaponId][nominationId][msg.sender] = Rating(
            initialRating,
            initialRd,
            initialVol
        );
    }

    function updateGlicko(
        uint8 weaponId,
        uint8 nominationId,
        address user,
        uint256 rating,
        uint256 rd,
        uint256 vol
    ) external {
        ratings[weaponId][nominationId][user] = Rating(rating, rd, vol);
        emit RatingUpdated(weaponId, user, rating, rd, vol);
    }

    function setName(
        address _user,
        string calldata _name
    ) external onlyUser(_user) {
        users[_user].name = _name;
        emit UserUpdated(
            _user,
            _name,
            users[_user].gender,
            users[_user].cityId,
            users[_user].countryId,
            users[_user].clubId
        );
    }

    function setGender(address _user, Gender _gender) external onlyUser(_user) {
        users[_user].gender = _gender;
        emit UserUpdated(
            _user,
            users[_user].name,
            _gender,
            users[_user].cityId,
            users[_user].countryId,
            users[_user].clubId
        );
    }

    function setCity(address _user, uint256 _cityId) external onlyUser(_user) {
        require(_cityId < cities.length || _cityId == 0, "Bad city");
        users[_user].cityId = _cityId;
        emit UserUpdated(
            _user,
            users[_user].name,
            users[_user].gender,
            _cityId,
            users[_user].countryId,
            users[_user].clubId
        );
    }

    function setCountry(
        address _user,
        uint256 _countryId
    ) external onlyUser(_user) {
        require(_countryId < countries.length, "Bad country");
        users[_user].countryId = _countryId;
        emit UserUpdated(
            _user,
            users[_user].name,
            users[_user].gender,
            users[_user].cityId,
            _countryId,
            users[_user].clubId
        );
    }

    function setClub(address _user, uint256 _clubId) external onlyUser(_user) {
        require(_clubId < clubs.length, "Bad club");
        users[_user].countryId = _clubId;
        emit UserUpdated(
            _user,
            users[_user].name,
            users[_user].gender,
            users[_user].cityId,
            users[_user].countryId,
            _clubId
        );
    }

    /* ---------- HELPERS ---------- */
    function addCity(string calldata _name) external {
        cities.push(_name);
    }

    function addCountry(string calldata _name) external {
        countries.push(_name);
    }

    function addClub(string calldata _name) external {
        clubs.push(_name);
    }

    function incFight(
        uint8 weaponId,
        uint8 nominationId,
        address user,
        bool win
    ) external {
        if (win) {
            wins[weaponId][nominationId][user]++;
        }
        fights[weaponId][nominationId][user]++;
    }

    function incTournament(
        uint8 weaponId,
        uint8 nominationId,
        address user
    ) external {
        tournamentsWins[weaponId][nominationId][user]++;
    }

    function getUser(address _user) external view returns (User memory) {
        return users[_user];
    }

    function getCities() external view returns (string[] memory) {
        return cities;
    }

    function getCountries() external view returns (string[] memory) {
        return countries;
    }

    function getClubs() external view returns (string[] memory) {
        return clubs;
    }

    function getAllUsers() external view returns (address[] memory) {
        return allUsers;
    }

    function getRating(
        uint8 weaponId,
        uint8 nominationId,
        address user
    ) external view returns (Rating memory) {
        return ratings[weaponId][nominationId][user];
    }

    function getNames(
        address[] calldata _users
    ) external view returns (string[] memory names) {
        names = new string[](_users.length);
        for (uint256 i = 0; i < _users.length; i++) {
            names[i] = users[_users[i]].name;
        }
        return names;
    }

    function getRatings(
        uint8 weaponId,
        uint8 nominationId,
        uint8 start,
        uint8 limit
    ) external view returns (User[] memory _users, Rating[] memory _ratings) {
        // Сначала соберем всех пользователей с ненулевым рейтингом
        uint256 totalCount = 0;
        for (uint256 i = 0; i < allUsers.length; i++) {
            if (ratings[weaponId][nominationId][allUsers[i]].rating != 0) {
                totalCount++;
            }
        }

        // Создаем временные массивы для сортировки
        User[] memory tempUsers = new User[](totalCount);
        Rating[] memory tempRatings = new Rating[](totalCount);
        uint256[] memory ratingValues = new uint256[](totalCount);
        uint256[] memory indices = new uint256[](totalCount);

        // Заполняем временные массивы
        uint256 currentIndex = 0;
        for (uint256 i = 0; i < allUsers.length; i++) {
            address userAddr = allUsers[i];
            Rating memory rating = ratings[weaponId][nominationId][userAddr];
            if (rating.rating != 0) {
                tempUsers[currentIndex] = users[userAddr];
                tempRatings[currentIndex] = rating;
                ratingValues[currentIndex] = rating.rating;
                indices[currentIndex] = currentIndex;
                currentIndex++;
            }
        }

        // Сортируем индексы по значению рейтинга (пузырьковая сортировка)
        for (uint256 i = 0; i < totalCount - 1; i++) {
            for (uint256 j = 0; j < totalCount - i - 1; j++) {
                bool shouldSwap = ratingValues[indices[j]] <
                    ratingValues[indices[j + 1]];

                if (shouldSwap) {
                    (indices[j], indices[j + 1]) = (indices[j + 1], indices[j]);
                }
            }
        }

        // Проверяем границы пагинации
        require(start < totalCount, "Start out of bounds");
        uint256 end = start + limit;
        if (end > totalCount) {
            end = totalCount;
        }
        uint256 resultCount = end - start;

        // Заполняем итоговые массивы с учетом пагинации
        _users = new User[](resultCount);
        _ratings = new Rating[](resultCount);

        for (uint256 i = start; i < end; i++) {
            uint256 sortedIndex = indices[i];
            _users[i - start] = tempUsers[sortedIndex];
            _ratings[i - start] = tempRatings[sortedIndex];
        }

        return (_users, _ratings);
    }
}
