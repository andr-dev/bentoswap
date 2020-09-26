var BentoToken = artifacts.require("./BentoToken.sol");

contract("BentoToken", function (accounts) {
  var tokenInstance;

  it("initializes contract with correct values", function () {
    return BentoToken.deployed()
      .then(function (instance) {
        tokenInstance = instance;
        return tokenInstance.name();
      })
      .then(function (name) {
        assert.equal(name, "Bento Token", "token is named correctly");
        return tokenInstance.symbol();
      })
      .then(function (symbol) {
        assert.equal(symbol, "BENTO", "token has correct symbol");
        return tokenInstance.standard();
      })
      .then(function (standard) {
        assert.equal(standard, "Bento Token v1.0", "token has correct standard");
      });
  });

  it("allocates the initial supply upon deployment", function () {
    return BentoToken.deployed()
      .then(function (instance) {
        tokenInstance = instance;
        return tokenInstance.totalSupply();
      })
      .then(function (totalSupply) {
        assert.equal(totalSupply.toNumber(), 271000, "sets the total supply to 271,000");
        return tokenInstance.balanceOf(accounts[0]);
      })
      .then(function (adminBalance) {
        assert.equal(adminBalance.toNumber(), 271000, "allocates initial supply of tokens to admin");
      });
  });

  it("transfers token ownership", function () {
    return BentoToken.deployed()
      .then(function (instance) {
        tokenInstance = instance;
        return tokenInstance.transfer(accounts[1], 271001);
      })
      .then(assert.fail)
      .catch(function (error) {
        assert(error.message.indexOf("revert") >= 0, "error message must contain revert");
        return tokenInstance.transfer.call(accounts[1], 23, {
          from: accounts[0],
        });
      })
      .then(function (success) {
        assert.equal(success, true, "transaction returns true");
        return tokenInstance.transfer(accounts[1], 23, { from: accounts[0] });
      })
      .then(function (receipt) {
        assert.equal(receipt.logs.length, 1, "transaction event length verified [1]");
        assert.equal(receipt.logs[0].event, "Transfer", "transfer event type verified");
        assert.equal(receipt.logs[0].args._from, accounts[0], "transfer event [_from] verified");
        assert.equal(receipt.logs[0].args._to, accounts[1], "transfer event [_to] verified");
        assert.equal(receipt.logs[0].args._value, 23, "transfer event [_value] verified");
        return tokenInstance.balanceOf(accounts[1]);
      })
      .then(function (balance) {
        assert.equal(balance.toNumber(), 23, "sent correct transaction quantity to reciever");
        return tokenInstance.balanceOf(accounts[0]);
      })
      .then(function (balance) {
        assert.equal(balance.toNumber(), 271000 - 23, "removed correct transaction quantity from sender");
      });
  });

  it("approves tokens for delegated transfer", function () {
    return BentoToken.deployed()
      .then(function (instance) {
        tokenInstance = instance;
        return tokenInstance.approve.call(accounts[1], 27);
      })
      .then(function (success) {
        assert.equal(success, true, "delegated transfer returns true");
        return tokenInstance.approve(accounts[1], 27);
      })
      .then(function (receipt) {
        assert.equal(receipt.logs.length, 1, "delegated transfer event length verified [1]");
        assert.equal(receipt.logs[0].event, "Approval", "delegated transfer event type verified");
        assert.equal(receipt.logs[0].args._owner, accounts[0], "delegated transfer event [_owner] verified");
        assert.equal(receipt.logs[0].args._spender, accounts[1], "delegated transfer event [_spender] verified");
        assert.equal(receipt.logs[0].args._value, 27, "delegated transfer event [_value] verified");
        return tokenInstance.allowance(accounts[0], accounts[1]);
      })
      .then(function (allowance) {
        assert.equal(allowance.toNumber(), 27, "delegated transfer allowance verified");
      });
  });

  it("handles delegated token transfers", function () {
    return BentoToken.deployed()
      .then(function (instance) {
        tokenInstance = instance;
        fromAccount = accounts[2];
        toAccount = accounts[3];
        spendingAccount = accounts[4];

        return tokenInstance.transfer(fromAccount, 100, { from: accounts[0] });
      })
      .then(function (receipt) {
        return tokenInstance.approve(spendingAccount, 25, { from: fromAccount });
      })
      .then(function (receipt) {
        // Test balance greater than available balance
        return tokenInstance.transferFrom(fromAccount, toAccount, 110, { from: spendingAccount });
      })
      .then(assert.fail)
      .catch(function (error) {
        assert(error.message.indexOf("revert") >= 0, "cannot transfer value larger than balance available");
        // Test balance greater than approved balance but less than available balance
        return tokenInstance.transferFrom(fromAccount, toAccount, 50, { from: spendingAccount });
      })
      .then(assert.fail)
      .catch(function (error) {
        assert(error.message.indexOf("revert") >= 0, "cannot transfer value larger than balance approved");
        return tokenInstance.transferFrom.call(fromAccount, toAccount, 10, { from: spendingAccount });
      })
      .then(function (success) {
        assert.equal(success, true);
        return tokenInstance.transferFrom(fromAccount, toAccount, 10, { from: spendingAccount });
      })
      .then(function (receipt) {
        assert.equal(receipt.logs.length, 1, "transaction event length verified [1]");
        assert.equal(receipt.logs[0].event, "Transfer", "transfer event type verified");
        assert.equal(receipt.logs[0].args._from, fromAccount, "transfer event [_from] verified");
        assert.equal(receipt.logs[0].args._to, toAccount, "transfer event [_to] verified");
        assert.equal(receipt.logs[0].args._value, 10, "transfer event [_value] verified");
        return tokenInstance.balanceOf(fromAccount);
      })
      .then(function (balance) {
        assert.equal(balance.toNumber(), 90, "verified transferFrom sender balance deduction");
        return tokenInstance.balanceOf(toAccount);
      })
      .then(function (balance) {
        assert.equal(balance.toNumber(), 10, "verified transferFrom reciever balance increase");
        return tokenInstance.allowance(fromAccount, spendingAccount);
      })
      .then(function (allowance) {
        assert.equal(allowance, 15, "verified tranferFrom allowance update");
      });
  });
});
