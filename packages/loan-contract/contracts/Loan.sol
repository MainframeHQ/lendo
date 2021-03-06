pragma solidity ^0.5.0;

import "zos-lib/contracts/Initializable.sol";
import "openzeppelin-eth/contracts/token/ERC20/IERC20.sol";

contract Loan is Initializable {

  function initialize(address _erc20Address) public initializer {
    erc20Address = _erc20Address;
  }

  // Stores the token asset ERC20 contract address
  address public erc20Address;

  struct LoanData {
    // Lender eth address
    address lender;

    // Borrower eth address
    address borrower;

    // Loan descriptive name
    string name;

    // Amount in DAI
    uint256 amount;

    // Due date for loan payment (in UNIX time seconds)
    uint256 dueDate;

    // Status
    LoanStatuses status;

    // Amount after interest in DAI
    uint256 expectedAmount;
  }

  enum LoanStatuses {

    // Borrower requested a loan to some contact
    Requested,

    // Lender approved a loan
    Approved,

    // Borrower paid the debt
    Paid
  }

  // Contains all created loans
  LoanData[] public loans;

  uint256 public totalLoanCount;

  // Addresses the loan data mapped by the lender address; One lender
  // can give money to many borrowers.
  //
  // The key is the lender address, the value is an array of numeric indexes
  // to elements from the loans array.
  mapping (address => uint256[]) public loansByLender;

  function loanCountByLender(address lender) public view returns (uint256) {
    return loansByLender[lender].length;
  }

  // Addresses the loan data mapped by the borrower address; One borrower
  // can borrow money from many lenders.
  //
  // The key is the borrower address, the value is an array of numeric indexes
  // to elements from the loans array.
  mapping (address => uint256[]) public loansByBorrower;

  function loanCountByBorrower(address borrower) public view returns (uint256) {
    return loansByBorrower[borrower].length;
  }

  event LoanRequested (
    address borrower,
    address lender,
    string name,
    uint256 dueDate
  );

  // Called by the borrower who wants to request money from a known lender
  //
  // Returns how many loans this borrower has already requested; the loan data
  // can be read by calling loansByBorrower[index] with this returned value.
  function requestLoan(address lender, string memory name, uint256 amount, uint256 dueDate, uint256 expectedAmount) public returns (uint256) {
    require(lender != msg.sender, "You can't borrow money from yourself");

    LoanData memory loan = LoanData(lender, msg.sender, name, amount, dueDate, LoanStatuses.Requested, expectedAmount);
    totalLoanCount = loans.push(loan);
    uint256 loanIdx = totalLoanCount - 1;
    loansByLender[lender].push(loanIdx);
    uint256 loanCount = loansByBorrower[msg.sender].push(loanIdx);

    emit LoanRequested(msg.sender, lender, name, dueDate);
    return loanCount;
  }

  // Called by the lender to approve a lend request made by a borrower
  function approveLoan(uint256 index) public {
    uint256 globalIndex = loansByLender[msg.sender][index];
    LoanData storage loan = loans[globalIndex];
    require(loan.status == LoanStatuses.Requested, "Loan must be in Requested status");

    // Check if the lender has previously approved this contract to spend
    // the necessary amount of tokens
    IERC20 dai = IERC20(erc20Address);

    require(dai.transferFrom(msg.sender, loan.borrower, loan.amount), "Could not transfer tokens to the borrower");
    loan.status = LoanStatuses.Approved;
  }

  // Called by the borrower to pay the debt
  function payDebt(uint256 index) public {
    uint256 globalIndex = loansByBorrower[msg.sender][index];
    LoanData storage loan = loans[globalIndex];
    require(loan.status == LoanStatuses.Approved, "Loan must be in Approved status");

    IERC20 dai = IERC20(erc20Address);

    require(dai.transferFrom(msg.sender, loan.lender, loan.expectedAmount), "Could not transfer tokens to the lender");
    loan.status = LoanStatuses.Paid;
  }

}
