//
//  ViewController.swift
//  Merseyside_bus
//
//  Created by Shivansh Raj on 30/03/2025.
//

import UIKit
import Firebase
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
class ViewController: UIViewController {
    
    @IBOutlet weak var headingLabel: UILabel!
    @IBOutlet weak var accountLabel: UILabel!
    @IBOutlet weak var emailLabel: UILabel!
    @IBOutlet weak var emailTextField: UITextField!
    
    @IBOutlet weak var termsLabel: UILabel!
    @IBOutlet weak var orLabel: UILabel!
    @IBAction func logInButton(_ sender: Any) {
        guard let email = emailTextField.text, !email.isEmpty else {
                   showErrorAlert(message: "Please enter your email.")
                   return
               }
               guard let password = passwordTF.text, !password.isEmpty else {
                   showErrorAlert(message: "Please enter your password.")
                   return
               }
               let db = Firestore.firestore()
               let manualUsersCollection = db.collection("manual_users")
               manualUsersCollection.whereField("email", isEqualTo: email).getDocuments { (querySnapshot, error) in
                   if let error = error {
                       print("Error checking existing user: \(error.localizedDescription)")
                       self.showErrorAlert(message: "Something went wrong. Please try again.")
                       return
                   }
                   if let documents = querySnapshot?.documents, let userDoc = documents.first {
                               let storedPassword = userDoc.data()["password"] as? String ?? ""
                               if storedPassword == password {
                                   
                                   manualUsersCollection.document(userDoc.documentID).updateData([
                                       "lastLoginAt": FieldValue.serverTimestamp()
                                   ]) { error in
                                       if let error = error {
                                           print("Error updating lastLoginAt: \(error.localizedDescription)")
                                       } else {
                                           print("Updated lastLoginAt successfully!")
                                       }
                                       self.performSegue(withIdentifier: "toMenu", sender: nil)
                                   }
                               } else {
                                   self.showErrorAlert(message: "Incorrect password. Please try again.")
                               }
                           } else {
                               self.showErrorAlert(message: "No account found with this email. Please sign up first.")
                           }
                       }
                   }
    @IBOutlet weak var passwordTF: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    
    }
    
    // MARK: - Manual Sign Up Button
    @IBAction func continueButtonTapped(_ sender: Any) {
        guard let email = emailTextField.text, !email.isEmpty else {
            showErrorAlert(message: "Please enter an email address")
            return
        }
        
        let db = Firestore.firestore()
        
        // Checks if the email already exists
        db.collection("users").whereField("email", isEqualTo: email).getDocuments { [weak self] (querySnapshot, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("Error checking existing email: \(error.localizedDescription)")
                self.showErrorAlert(message: "An error occurred. Please try again.")
                return
            }
            
            if let documents = querySnapshot?.documents, !documents.isEmpty {
                // If email already exists then show an alert
                let alert = UIAlertController(
                    title: "Email Already Registered",
                    message: "This email is already registered. Please login with these credentials.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self.present(alert, animated: true)
                return
            }
            
            // If email doesn't exist, proceed with sign-up
            let uid = UUID().uuidString
            
            let userData: [String: Any] = [
                "email": email,
                "displayName": self.accountLabel.text ?? "",
                "photoURL": "", 
                "uid": uid,
                "createdAt": FieldValue.serverTimestamp(),
                "signInMethod": "Manual"
            ]
            
            db.collection("manual_users").document(uid).setData(userData) { error in
                if let error = error {
                    print("Error saving manual user to Firestore: \(error.localizedDescription)")
                    self.showErrorAlert(message: "Failed to save user. Please try again.")
                } else {
                    print("Manual user saved successfully to Firestore!")
                    self.performSegue(withIdentifier: "toMenu", sender: nil)
                }
            }
        }
    }
        // MARK: - Google Sign In
        @IBAction func googleSignInButtonTapped(_ sender: Any) {
            if let button = sender as? UIButton {
                button.isEnabled = false
            }
            let loadingIndicator = UIActivityIndicatorView(style: .medium)
            loadingIndicator.center = self.view.center
            loadingIndicator.tag = 999
            loadingIndicator.startAnimating()
            self.view.addSubview(loadingIndicator)
            GIDSignIn.sharedInstance.signOut()
            guard let clientID = FirebaseApp.app()?.options.clientID else {
                handleSignInCompletion(success: false, error: "Configuration error")
                return
            }
            let config = GIDConfiguration(clientID: clientID)
            GIDSignIn.sharedInstance.configuration = config
            attemptGoogleSignIn(retryCount: 3)
        }
        func attemptGoogleSignIn(retryCount: Int) {
            guard retryCount > 0 else {
                handleSignInCompletion(success: false, error: "Maximum retries exceeded")
                return
            }
            guard let presentingVC = self.getTopViewController() else {
                handleSignInCompletion(success: false, error: "Unable to present sign-in")
                return
            }
            var timeoutWorkItem: DispatchWorkItem?
            timeoutWorkItem = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                if retryCount > 1 {
                    print("Sign-in attempt timed out, retrying... (\(retryCount-1) attempts left)")
                    self.attemptGoogleSignIn(retryCount: retryCount - 1)
                } else {
                    self.handleSignInCompletion(success: false, error: "Connection timed out")
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 10.0, execute: timeoutWorkItem!)
            GIDSignIn.sharedInstance.signIn(withPresenting: presentingVC) { [weak self] result, error in
                guard let self = self else { return }
                timeoutWorkItem?.cancel()
                if let error = error {
                    print("Google Sign-In error: \(error.localizedDescription)")
                    if self.isNetworkRelatedError(error) && retryCount > 1 {
                        print("Network-related error, retrying... (\(retryCount-1) attempts left)")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            self.attemptGoogleSignIn(retryCount: retryCount - 1)
                        }
                        return
                    }
                    self.handleSignInCompletion(success: false, error: "Authentication failed")
                    return
                }
                guard let user = result?.user,
                      let idToken = user.idToken?.tokenString else {
                    self.handleSignInCompletion(success: false, error: "Missing user data")
                    return
                }
                let accessToken = user.accessToken.tokenString
                let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
                var firebaseTimeoutWorkItem: DispatchWorkItem?
                firebaseTimeoutWorkItem = DispatchWorkItem { [weak self] in
                    guard let self = self else { return }
                    self.handleSignInCompletion(success: false, error: "Firebase authentication timed out")
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 8.0, execute: firebaseTimeoutWorkItem!)
                Auth.auth().signIn(with: credential) { [weak self] authResult, error in
                    guard let self = self else { return }
                    firebaseTimeoutWorkItem?.cancel()
                    if let error = error {
                        print("Firebase auth error: \(error.localizedDescription)")
                        self.handleSignInCompletion(success: false, error: "Firebase authentication failed")
                        return
                    }
                    if let user = authResult?.user {
                        self.saveUserToFirestore(user: user) { success in
                            self.handleSignInCompletion(success: success)
                        }
                    } else {
                        self.handleSignInCompletion(success: true)
                    }
                }
            }
        }
        func saveUserToFirestore(user: User, completion: @escaping (Bool) -> Void) {
            let db = Firestore.firestore()
            let userData: [String: Any] = [
                "email": user.email ?? "",
                "displayName": user.displayName ?? "",
                "photoURL": user.photoURL?.absoluteString ?? "",
                "uid": user.uid,
                "createdAt": FieldValue.serverTimestamp(),
                "signInMethod": "Google",
                "lastSignIn": FieldValue.serverTimestamp()
            ]
            db.collection("users").document(user.uid).setData(userData, merge: true) { error in
                if let error = error {
                    print("Error saving Google user: \(error.localizedDescription)")
                    completion(false)
                } else {
                    print("Google user saved successfully!")
                    completion(true)
                }
            }
        }
        func handleSignInCompletion(success: Bool, error: String? = nil) {
            hideLoadingIndicator()
            for case let button as UIButton in self.view.subviews {
                button.isEnabled = true
            }
            if success {
                self.performSegue(withIdentifier: "toMenu", sender: nil)
            } else if let errorMessage = error {
                showErrorAlert(message: errorMessage)
            }
        }
        func isNetworkRelatedError(_ error: Error) -> Bool {
            let nsError = error as NSError
            let networkErrorDomains = ["NSURLErrorDomain", "com.google.HTTPStatus"]
            let networkErrorCodes = [-1001, -1003, -1004, -1005, -1009]
            return networkErrorDomains.contains(nsError.domain) ||
                   networkErrorCodes.contains(nsError.code) ||
                   nsError.localizedDescription.lowercased().contains("network") ||
                   nsError.localizedDescription.lowercased().contains("connection")
        }
        func hideLoadingIndicator() {
            if let loadingIndicator = view.viewWithTag(999) {
                loadingIndicator.removeFromSuperview()
            }
        }
        func showErrorAlert(message: String) {
            let alert = UIAlertController(title: "Sign-In Issue", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
        func getTopViewController() -> UIViewController? {
            guard let window = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .first?.windows
                    .first(where: { $0.isKeyWindow }) else {
                return nil
            }
            var topController = window.rootViewController
            while let presentedViewController = topController?.presentedViewController {
                topController = presentedViewController
            }
            return topController
        }
    }


