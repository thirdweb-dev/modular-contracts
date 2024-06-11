interface IERC7572 {
    function contractURI() external view returns (string memory);

    event ContractURIUpdated();
}
