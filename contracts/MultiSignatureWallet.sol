// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.4;

contract MultiSignatureWallet {
    address[] public owners;
    uint public required;
    uint transactionCount;
    mapping (address => bool) isOwner;
    mapping (uint => Transaction) public transactions;
    mapping (uint => mapping(address => bool)) public confirmations;

    struct Transaction {
      address destination;
      uint value;
      bytes data;
      bool executed;
    }

    event Deposit(address indexed sender, uint value);
    event Submission(uint indexed transactionId);
    event Confirmation(address indexed sender, uint indexed transactionId);
    event Execution(uint indexed transactionId);
    event ExecutionFailure(uint indexed transactionId);

    /// @dev receive function allows to deposit ether.
    receive()
    	external
        payable
    {
        emit Deposit(msg.sender, msg.value);
    }
    
    modifier validRequirement(uint _ownerCount, uint _required) {
        if (   _required > _ownerCount || _required == 0 || _ownerCount == 0)
            revert();
        _;
    }

    /*
     * Public functions
     */
    /// @dev Contract constructor sets initial owners and required number of confirmations.
    /// @param _owners List of initial owners.
    /// @param _required Number of required confirmations.
    constructor(address[] memory _owners, uint _required) validRequirement(_owners.length, _required) {
        for (uint i=0; i<_owners.length; i++) {
              isOwner[_owners[i]] = true;
          }
          
          owners = _owners;
          required = _required;
    }

    /// @dev Allows an owner to submit and confirm a transaction.
    /// @param _destination Transaction target address.
    /// @param _value Transaction ether value.
    /// @param _data Transaction data payload.
    /// @return transactionId Returns transaction ID.
    function submitTransaction(address _destination, uint _value, bytes memory _data) public returns (uint transactionId) {
        require(isOwner[msg.sender]);
        transactionId = addTransaction(_destination, _value, _data);
        confirmTransaction(transactionId);
    }

    /// @dev Allows an owner to confirm a transaction.
    /// @param transactionId Transaction ID.
    function confirmTransaction(uint transactionId) public {
        require(isOwner[msg.sender]);
        require(transactions[transactionId].destination != address(0));
        require(confirmations[transactionId][msg.sender] == false);
        
        confirmations[transactionId][msg.sender] = true;
        emit Confirmation(msg.sender, transactionId);
        executeTransaction(transactionId);
    }

    /// @dev Allows an owner to revoke a confirmation for a transaction.
    /// @param transactionId Transaction ID.
    function revokeConfirmation(uint transactionId) public {}

    /// @dev Allows anyone to execute a confirmed transaction.
    /// @param transactionId Transaction ID.
    function executeTransaction(uint transactionId) public {
        require(transactions[transactionId].executed == false);
        if (isConfirmed(transactionId)) {
            Transaction storage t = transactions[transactionId];
            t.executed = true;
            (bool success, bytes memory returnedData) = t.destination.call{value: t.value}(t.data);
            if (success) {
                emit Execution(transactionId);
            } else {
                emit ExecutionFailure(transactionId);
                t.executed = false;
            }
        }
    }

		/*
		 * (Possible) Helper Functions
		 */
    /// @dev Returns the confirmation status of a transaction.
    /// @param transactionId Transaction ID.
    /// @return Confirmation status.
    function isConfirmed(uint transactionId) internal view returns (bool) {
        uint count = 0;
        for (uint i = 0; i < owners.length; i++) {
            if (confirmations[transactionId][owners[i]]) {
                count++;
            }
            if (count == required) {
                return true;
            }
        }
    }

    /// @dev Adds a new transaction to the transaction mapping, if transaction does not exist yet.
    /// @param _destination Transaction target address.
    /// @param _value Transaction ether value.
    /// @param _data Transaction data payload.
    /// @return transactionId Returns transaction ID.
    function addTransaction(address _destination, uint _value, bytes memory _data) internal returns (uint transactionId) {
        transactionId = transactionCount;
        transactions[transactionId] = Transaction({
            destination: _destination,
            value: _value,
            data: _data,
            executed: false
        });
        transactionCount += 1;
        emit Submission(transactionId);
    }
}
