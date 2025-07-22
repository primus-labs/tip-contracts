import "@sunscreen/contracts/Spf.sol";

/**
 * Calls to the off-chain Secure Processing Framework (SPF) library for Primus FHE.
 *
 * All functions here have a corresponding function in the
 * `fhe-programs/src/primus-fhe.c` library. Please refer to that file for the
 * implementation details.
 */
library PrimusSpf {
    /**
     * To update this value, compile the SPF library and then acquire the hash
     * by uploading the resulting program to the SPF server. Please see the README
     * for instructions on how to generate this identifier.
     */
    Spf.SpfLibrary public constant PRIMUS_TIP_SPF_LIBRARY =
        Spf.SpfLibrary.wrap(0xc57120724dfd69eb50b284688d35fd748a7c6efa956e379092b8eb3ac9f921ea);

    // These program names should match the function names in the `primus-fhe.c` file.
    Spf.SpfProgram public constant PRIMUS_UPDATE_TIP_PROGRAM = Spf.SpfProgram.wrap("updateTip");
    Spf.SpfProgram public constant PRIMUS_ADD_TO_BALANCE_PROGRAM = Spf.SpfProgram.wrap("addToBalance");
    Spf.SpfProgram public constant PRIMUS_WITHDRAW_PROGRAM = Spf.SpfProgram.wrap("withdraw");

    /**
     * Update the tip amount and spent amount for the user, checking that the
     * user has enough balance to tip.
     *
     * @param amount The amount to tip (encrypted).
     * @param balance The current balance of the user (plaintext).
     * @param spent The current spent amount of the user (encrypted).
     * @return updatedAmount The updated amount after the tip (encrypted).
     * @return updatedSpent The updated spent amount after the tip (encrypted).
     */
    function updateTip(Spf.SpfParameter memory amount, uint256 balance, Spf.SpfParameter memory spent)
        internal
        returns (Spf.SpfRunHandle, Spf.SpfParameter memory, Spf.SpfParameter memory)
    {
        // Pack the parameters for the SPF program.
        Spf.SpfParameter[] memory parameters = new Spf.SpfParameter[](6);
        parameters[0] = Spf.createPlaintextParameter(64, 0); // zero
        parameters[1] = amount;
        parameters[2] = Spf.createPlaintextParameter(64, balance); // balance
        parameters[3] = spent;
        parameters[4] = Spf.createOutputCiphertextParameter(64); // updatedAmount
        parameters[5] = Spf.createOutputCiphertextParameter(64); // updatedSpent

        // Notify the SPF server to run the program with the given parameters.
        Spf.SpfRunHandle runHandle = Spf.requestSpf(PRIMUS_TIP_SPF_LIBRARY, PRIMUS_UPDATE_TIP_PROGRAM, parameters);

        // Derive the updated amount and spent handles
        Spf.SpfParameter memory updatedAmount = Spf.getOutputHandle(runHandle, 0);
        Spf.SpfParameter memory updatedSpent = Spf.getOutputHandle(runHandle, 1);

        return (runHandle, updatedAmount, updatedSpent);
    }

    /**
     * Add the given amount to the user's balance.
     *
     * @param amount The amount to add (encrypted).
     * @param balance The current balance of the user (encrypted).
     * @return updatedBalance The updated balance after adding the amount (encrypted).
     */
    function addToBalance(Spf.SpfParameter memory amount, Spf.SpfParameter memory balance)
        internal
        returns (Spf.SpfRunHandle, Spf.SpfParameter memory)
    {
        Spf.SpfParameter[] memory parameters = new Spf.SpfParameter[](4);
        parameters[0] = Spf.createPlaintextParameter(64, 0); // zero
        parameters[1] = amount;
        parameters[2] = balance;
        parameters[3] = Spf.createOutputCiphertextParameter(64); // updatedBalance

        Spf.SpfRunHandle runHandle = Spf.requestSpf(PRIMUS_TIP_SPF_LIBRARY, PRIMUS_ADD_TO_BALANCE_PROGRAM, parameters);

        Spf.SpfParameter memory updatedBalance = Spf.getOutputHandle(runHandle, 0);

        return (runHandle, updatedBalance);
    }

    /**
     * Withdraw the specified amount from the user's balance.
     *
     * @param amount The amount to withdraw (plaintext).
     * @param balance The current balance of the user (encrypted).
     * @return updatedAmount The updated amount after the withdrawal (encrypted).
     * @return updatedBalance The updated balance after the withdrawal (encrypted).
     */
    function withdraw(uint64 amount, Spf.SpfParameter memory balance)
        internal
        returns (Spf.SpfRunHandle, Spf.SpfParameter memory, Spf.SpfParameter memory)
    {
        Spf.SpfParameter[] memory parameters = new Spf.SpfParameter[](5);
        parameters[0] = Spf.createPlaintextParameter(64, 0); // zero
        parameters[1] = Spf.createPlaintextParameter(64, amount); // amount to withdraw
        parameters[2] = balance;
        parameters[3] = Spf.createOutputCiphertextParameter(64); // updatedAmount
        parameters[4] = Spf.createOutputCiphertextParameter(64); // updatedBalance

        Spf.SpfRunHandle runHandle = Spf.requestSpf(PRIMUS_TIP_SPF_LIBRARY, PRIMUS_WITHDRAW_PROGRAM, parameters);

        Spf.SpfParameter memory updatedAmount = Spf.getOutputHandle(runHandle, 0);
        Spf.SpfParameter memory updatedBalance = Spf.getOutputHandle(runHandle, 1);

        return (runHandle, updatedAmount, updatedBalance);
    }
}
