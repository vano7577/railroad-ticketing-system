'use strict';

let {check_login_password} = require("./db.js");

describe('testing_login&password',()=>{
    test('Correct_account_info', () => {
        const login = 'petrov0405'
        const password = 'password1'
        const account_id = 1;
        assert.equal(check_login_password(login,password), account_id);
    });
    test('Incorrect_account_info', () => {
        const login = 'petrov0405'
        const password = 'password0'
        const account_id = 1;
        assert.notEqual(check_login_password(login,password), account_id);
    });
    test('Incorrect_account_login', () => {
        const login = 'petrov0400'
        const password = 'password0'
        const account_id = 1;
        assert.throws(check_login_password(login,password),'can not find account')
    });
})
