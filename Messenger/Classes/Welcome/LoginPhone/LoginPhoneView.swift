//
// Copyright (c) 2020 Related Code - http://relatedcode.com
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import FirebaseAuth
import ProgressHUD

//-------------------------------------------------------------------------------------------------------------------------------------------------
@objc protocol LoginPhoneDelegate: class {

	func didLoginUserPhone()
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
class LoginPhoneView: UIViewController {

	@IBOutlet weak var delegate: LoginPhoneDelegate?

	@IBOutlet var labelName: UILabel!
	@IBOutlet var labelCode: UILabel!
	@IBOutlet var fieldPhone: UITextField!

	private var buttonRight: UIBarButtonItem?

	private var verificationID = ""

	//---------------------------------------------------------------------------------------------------------------------------------------------
	override func viewDidLoad() {

		super.viewDidLoad()
		title = "Phone Login"

		navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(actionDismiss))

		buttonRight = UIBarButtonItem(title: "Next", style: .plain, target: self, action: #selector(actionVerifyNumber))

		let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
		view.addGestureRecognizer(gestureRecognizer)
		gestureRecognizer.cancelsTouchesInView = false

		if let countries = NSArray(contentsOfFile: Dir.application("countries.plist")) {
			if let country = countries[Int(DEFAULT_COUNTRY)] as? [String: String] {
				labelName.text = country["name"]
				labelCode.text = country["dial_code"]
			}
		}
	}

	//---------------------------------------------------------------------------------------------------------------------------------------------
	override func viewWillDisappear(_ animated: Bool) {

		super.viewWillDisappear(animated)

		dismissKeyboard()
	}

	//---------------------------------------------------------------------------------------------------------------------------------------------
	@objc func dismissKeyboard() {

		view.endEditing(true)
	}

	// MARK: - User actions
	//---------------------------------------------------------------------------------------------------------------------------------------------
	@objc func actionDismiss() {

		dismiss(animated: true)
	}

	//---------------------------------------------------------------------------------------------------------------------------------------------
	@IBAction func actionCountries(_ sender: Any) {

		let countriesView = CountriesView()
		countriesView.delegate = self
		let navController = NavigationController(rootViewController: countriesView)
		present(navController, animated: true)
	}

	//---------------------------------------------------------------------------------------------------------------------------------------------
	@objc func actionVerifyNumber() {

		let code = labelCode.text ?? ""
		let phone = fieldPhone.text ?? ""
		let number = "\(code)\(phone)"

		dismissKeyboard()
		ProgressHUD.show(nil, interaction: false)

		PhoneAuthProvider.provider().verifyPhoneNumber(number, uiDelegate: nil) { verificationID, error in
			if let error = error {
				ProgressHUD.showError(error.localizedDescription)
			} else {
				ProgressHUD.dismiss()
				self.actionVerifyCodeView()
				self.verificationID = verificationID!
			}
		}
	}

	//---------------------------------------------------------------------------------------------------------------------------------------------
	func actionVerifyCodeView() {

		let code = labelCode.text ?? ""
		let phone = fieldPhone.text ?? ""

		let verifyCodeView = VerifyCodeView(countryCode: code, phoneNumber: phone)
		verifyCodeView.delegate = self
		let navController = NavigationController(rootViewController: verifyCodeView)
		self.present(navController, animated: true)
	}

	//---------------------------------------------------------------------------------------------------------------------------------------------
	func actionDidVerifyCode(_ verificationCode: String) {

		ProgressHUD.show(nil, interaction: false)

		let credential = PhoneAuthProvider.provider().credential(withVerificationID: verificationID, verificationCode: verificationCode)
		AuthUser.signIn(credential: credential) { error in
			if let error = error {
				ProgressHUD.showError(error.localizedDescription)
			} else {
				self.loadPerson()
			}
		}
	}

	// MARK: -
	//---------------------------------------------------------------------------------------------------------------------------------------------
	func loadPerson() {

		let userId = AuthUser.userId()
		DataFetcher.fetchPerson(userId) { error in
			if (error != nil) {
				self.createPerson()
			}
			self.dismiss(animated: true) {
				self.delegate?.didLoginUserPhone()
			}
		}
	}

	//---------------------------------------------------------------------------------------------------------------------------------------------
	func createPerson() {

		let code = labelCode.text ?? ""
		let phone = fieldPhone.text ?? ""
		let number = "\(code)\(phone)"

		let userId = AuthUser.userId()
		Persons.create(userId, phone: number)
	}
}

// MARK: - CountriesDelegate
//-------------------------------------------------------------------------------------------------------------------------------------------------
extension LoginPhoneView: CountriesDelegate {

	//---------------------------------------------------------------------------------------------------------------------------------------------
	func didSelectCountry(name: String, code: String) {

		labelName.text = name
		labelCode.text = code
		fieldPhone.becomeFirstResponder()
	}
}

// MARK: - VerifyCodeDelegate
//-------------------------------------------------------------------------------------------------------------------------------------------------
extension LoginPhoneView: VerifyCodeDelegate {

	//---------------------------------------------------------------------------------------------------------------------------------------------
	func didVerifyCode(verificationCode: String) {

		actionDidVerifyCode(verificationCode)
	}
}

// MARK: - UITextFieldDelegate
//-------------------------------------------------------------------------------------------------------------------------------------------------
extension LoginPhoneView: UITextFieldDelegate {

	//---------------------------------------------------------------------------------------------------------------------------------------------
	func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {

		let text = (textField.text ?? "") as NSString
		let phone = text.replacingCharacters(in: range, with: string)
		navigationItem.rightBarButtonItem = (phone.count != 0) ? buttonRight : nil

		return true
	}
}