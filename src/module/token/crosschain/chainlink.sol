
library ChainlinkCrossChainStorage {

    /// @custom:storage-location erc7201:token.minting.chainlinkcrosschain
    bytes32 public constant CHAINLINKCROSSCHAIN_STORAGE_POSITION =
        keccak256(abi.encode(uint256(keccak256("token.minting.chainlinkcrosschain.erc721")) - 1)) & ~bytes32(uint256(0xff));

    struct Data {
        address router;
        address s_linkToken;
    }

    function data() internal pure returns (Data storage data_) {
        bytes32 position = CHAINLINKCROSSCHAIN_STORAGE_POSITION;
        assembly {
            data_.slot := position
        }
    }

}


contract ChainlinkCrossChain is CCIPReceiver, OwnerIsCreator {

    address immutable s_linkToken;
    address immutable router;

    constructor(address _router, address _link) {
        s_linkToken = _link;
        router = _router;
    }

    function bridgeWithToken(
        address _destinationChain,
        address _recipient,
        bytes memory _data,
        address _token,
        uint256 _amount,
        bytes memory _extraArgs,
    ) external {
        (uint256 _feeTokenAddress, ccipMessageExtraArgs) = abi.decode(_extraArgs, (uint256, bytes));

        Client.EVM2AnyMessage memory evm2AnyMessage =
            _buildCCIPMessage(_receiver, _text, _token, _amount, _feeTokenAddress, ccipMessageExtraArgs);

        // Initialize a router client instance to interact with cross-chain router
        IRouterClient router = IRouterClient(_chainLinkCrossChainStorage().router);

        // Get the fee required to send the CCIP message
        uint256 fees = router.getFee(_destinationChainSelector, evm2AnyMessage);

        if (fees > s_linkToken.balanceOf(address(this))) {
            revert NotEnoughBalance(s_linkToken.balanceOf(address(this)), fees);
        }

        // approve the Router to transfer LINK tokens on contract's behalf. It will spend the fees in LINK
        s_linkToken.approve(address(router), fees);

        // approve the Router to spend tokens on contract's behalf. It will spend the amount of the given token
        IERC20(_token).approve(address(router), _amount);

        // Send the message through the router and store the returned message ID
        messageId = router.ccipSend(_destinationChainSelector, evm2AnyMessage);

        // Emit an event with message details
        emit MessageSent(
            messageId, _destinationChainSelector, _receiver, _text, _token, _amount, address(s_linkToken), fees
        );

        // Return the message ID
        return messageId;
    }

    /// @notice Sends data and transfer tokens to receiver on the destination chain.
    /// @notice Pay for fees in native gas.
    /// @dev Assumes your contract has sufficient native gas like ETH on Ethereum or POL on Polygon.
    /// @param _destinationChainSelector The identifier (aka selector) for the destination blockchain.
    /// @param _receiver The address of the recipient on the destination blockchain.
    /// @param _text The string data to be sent.
    /// @param _token token address.
    /// @param _amount token amount.
    /// @return messageId The ID of the CCIP message that was sent.
    function sendMessagePayNative(
        uint64 _destinationChainSelector,
        address _receiver,
        string calldata _text,
        address _token,
        uint256 _amount
    )
        external
        onlyOwner
        onlyAllowlistedDestinationChain(_destinationChainSelector)
        validateReceiver(_receiver)
        returns (bytes32 messageId)
    {
        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        // address(0) means fees are paid in native gas
        Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(_receiver, _text, _token, _amount, address(0));

        // Initialize a router client instance to interact with cross-chain router
        IRouterClient router = IRouterClient(this.getRouter());

        // Get the fee required to send the CCIP message
        uint256 fees = router.getFee(_destinationChainSelector, evm2AnyMessage);

        if (fees > address(this).balance) {
            revert NotEnoughBalance(address(this).balance, fees);
        }

        // approve the Router to spend tokens on contract's behalf. It will spend the amount of the given token
        IERC20(_token).approve(address(router), _amount);

        // Send the message through the router and store the returned message ID
        messageId = router.ccipSend{value: fees}(_destinationChainSelector, evm2AnyMessage);

        // Emit an event with message details
        emit MessageSent(messageId, _destinationChainSelector, _receiver, _text, _token, _amount, address(0), fees);

        // Return the message ID
        return messageId;
    }


    /// @notice Construct a CCIP message.
    /// @dev This function will create an EVM2AnyMessage struct with all the necessary information for programmable tokens transfer.
    /// @param _receiver The address of the receiver.
    /// @param _text The string data to be sent.
    /// @param _token The token to be transferred.
    /// @param _amount The amount of the token to be transferred.
    /// @param _feeTokenAddress The address of the token used for fees. Set address(0) for native gas.
    /// @return Client.EVM2AnyMessage Returns an EVM2AnyMessage struct which contains information for sending a CCIP message.
    function _buildCCIPMessage(
        address _recipient
        bytes calldata _data,
        address _token,
        uint256 _amount,
        address _feeTokenAddress,
        bytes calldata _extraArgs
    ) private pure returns (Client.EVM2AnyMessage memory) {
        // Set the token amounts
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: _token, amount: _amount});
        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        return Client.EVM2AnyMessage({
            receiver: abi.encode(_recipient), // ABI-encoded receiver address
            data: _data,
            tokenAmounts: tokenAmounts, // The amount and type of token being transferred
            extraArgs: _extraArgs,
            // Set the feeToken to a feeTokenAddress, indicating specific asset will be used for fees
            feeToken: _feeTokenAddress
        });
    }

    function _chainlinkCrossChainStorage() internal pure returns (ChainlinkCrossChainStorage.Data storage) {
        return ChainlinkCrossChainStorage.data();
    }

}
