const { assert } = require("chai");

// const ExposureNetwork = artifacts.require("ExposureNetwork");
const ExposureNetwork = artifacts.require("ExposureNetworkTest");


contract('ExposureNetwork', (accounts) => {

  let contractInstance;
  let accountOne;
  let accountTwo;

  beforeEach(async () => {
    accountOne = accounts[0];
    accountTwo = accounts[1];
    contractInstance = await ExposureNetwork.new("Contract Name", "SYM", 1000, accountOne);
  });


  it('should put 10000 MetaCoin in the first account', async () => {
    
    // Read the balance and check it is correct.
    const balance = (await contractInstance.balanceOf(accounts[0])).toNumber();
    assert.equal(balance.valueOf(), 1000, "1000 wasn't in the first account");
  });
  
  
  it('should allow adding exposure', async () => {
    
    // Setup 2 accounts.
    
    const amount = 100;
    await contractInstance.transfer(accountTwo, amount, { from: accountOne });

    let old_exposure = (await contractInstance.currentExposureAmount.call(accountTwo, accountOne)).toNumber();
    // Now add exposure.
    await contractInstance.increaseExposure(accountOne, 50,  { from: accountTwo });
    let new_exposure = (await contractInstance.currentExposureAmount.call(accountTwo, accountOne)).toNumber();

    assert.equal(old_exposure + 50, new_exposure, 'Library function returned unexpected function, linkage may be broken');
  });

  it('should not allow decreasing exposure before expiry', async () => {
    
    // Setup 2 accounts.
    
    const amount = 100;
    await contractInstance.transfer(accountTwo, amount, { from: accountOne });
    await contractInstance.increaseExposure(accountOne, 50,  { from: accountTwo });

    try{
      await contractInstance.reduceExposure(accountOne, 50,  { from: accountTwo });
      assert.ok(false, "Must now allow reduction so soon.");
    }
    catch(error){}

    let new_exposure = (await contractInstance.currentExposureAmount.call(accountTwo, accountOne)).toNumber();
    assert.equal(50, new_exposure, 'Library function returned unexpected function, linkage may be broken');
  
  });

  it('should allow decreasing exposure after expiry', async () => {
    
    // Setup 2 accounts.
    
    const amount = 100;
    await contractInstance.transfer(accountTwo, amount, { from: accountOne });
    await contractInstance.increaseExposure(accountOne, 50,  { from: accountTwo });

    let expiry = (await contractInstance.currentExposureExpiry.call(accountTwo, accountOne)).toNumber();
    
    // Advance time.
    (await contractInstance._test_set_time(expiry + 10, {from: accountOne}));

    // Now we can reduce the exposure.
    await contractInstance.reduceExposure(accountOne, 50,  { from: accountTwo });

    let new_exposure = (await contractInstance.currentExposureAmount.call(accountTwo, accountOne)).toNumber();
    assert.equal(0, new_exposure, 'Library function returned unexpected function, linkage may be broken');
  
  });

  it('should not allow adding exposure beyond its balance', async () => {
    
    // Setup 2 accounts.
    const amount = 100;
    await contractInstance.transfer(accountTwo, amount, { from: accountOne });

    let old_exposure = (await contractInstance.currentExposureAmount.call(accountTwo, accountOne)).toNumber();
    // Now add exposure.

    try{
      await contractInstance.increaseExposure(accountOne, 150,  { from: accountTwo });
      assert.ok(false, "Exposure amount cannot exceed balance.");
    }
    catch(error){}
    
      let new_exposure = (await contractInstance.currentExposureAmount.call(accountTwo, accountOne)).toNumber();

    assert.equal(old_exposure, new_exposure, 'Library function returned unexpected function, linkage may be broken');
  });
  it('should send coin correctly', async () => {

    // Get initial balances of first and second account.
    const accountOneStartingBalance = (await contractInstance.balanceOf.call(accountOne)).toNumber();
    const accountTwoStartingBalance = (await contractInstance.balanceOf.call(accountTwo)).toNumber();

    // Make transaction from first account to second.
    const amount = 10;
    await contractInstance.transfer(accountTwo, amount, { from: accountOne });

    // Get balances of first and second account after the transactions.
    const accountOneEndingBalance = (await contractInstance.balanceOf.call(accountOne)).toNumber();
    const accountTwoEndingBalance = (await contractInstance.balanceOf.call(accountTwo)).toNumber();

    assert.equal(accountOneEndingBalance, accountOneStartingBalance - amount, "Amount wasn't correctly taken from the sender");
    assert.equal(accountTwoEndingBalance, accountTwoStartingBalance + amount, "Amount wasn't correctly sent to the receiver");
  });
});
