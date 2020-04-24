//
//  ImportWalletViewController.swift
//  EosioReferenceAuthenticator

//  Created by Shawn Lee on 2020/4/20
//  Copyright (c) 2017-2020 block.one and its contributors. All rights reserved.
//


import UIKit
import EosioSwiftEcc
import EosioSwiftVault
import EOSWallet

class DocumentBrowserViewController: UINavigationController {
    let browserViewController: UIDocumentBrowserViewController
    
    init() {
        browserViewController = UIDocumentBrowserViewController(forOpeningFilesWithContentTypes: ["jp.laomao.authenticator"])
        browserViewController.allowsDocumentCreation = false
        browserViewController.allowsPickingMultipleItems = false
        browserViewController.shouldShowFileExtensions = true
        super.init(rootViewController: browserViewController)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let backItem = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(backAction))
        browserViewController.navigationItem.leftBarButtonItem = backItem
    }
    
    @objc func backAction() {
        self.dismiss(animated: true, completion: nil)
    }
}

class ImportWalletViewController: UIViewController, ImportKey {
    
    let vault: EosioVault = EosioVault(accessGroup: Constants.vaultAccessGroup)
    
    @IBOutlet var nicknameField: UITextField!
    @IBOutlet var textView: UITextView!
    @IBOutlet var openFileBtn: UIButton!
    
    var accessoryViewBottom: NSLayoutConstraint!
    lazy var accessoryView: UIView = {
        let accessoryView = UIView()
        accessoryView.backgroundColor = UIColor(white: 1, alpha: 0.8)
        accessoryView.translatesAutoresizingMaskIntoConstraints = false
        let btn = UIButton(type: .custom)
        btn.addTarget(self, action: #selector(dismissKeyboard(_:)), for: .touchUpInside)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.setImage(UIImage(named: "dismissKeyboard"), for: .normal)
        btn.sizeToFit()
        accessoryView.addSubview(btn)
        accessoryView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:[btn]-16-|", options: [], metrics: nil, views: ["btn": btn]))
        accessoryView.addConstraint(NSLayoutConstraint(item: btn, attribute: .centerY, relatedBy: .equal, toItem: accessoryView, attribute: .centerY, multiplier: 1.0, constant: 0))
        return accessoryView
    }()
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Add Auth"
        
        self.navigationController?.navigationBar.prefersLargeTitles = true
        self.navigationController?.navigationBar.largeTitleTextAttributes = EosioAppearance.navBarLargeTitleAttributes
        
        textView.layer.borderColor = UIColor.customDarkBlue.cgColor
        textView.layer.borderWidth = 1.0
        textView.layer.cornerRadius = 6.0
        
        view.addSubview(accessoryView)
        accessoryViewBottom = NSLayoutConstraint(item: accessoryView, attribute: .bottom, relatedBy: .equal, toItem: view, attribute: .bottom, multiplier: 1, constant: 40)
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[accessory]|", options: [], metrics: nil, views: ["accessory": accessoryView]))
        view.addConstraints([accessoryViewBottom, NSLayoutConstraint(item: accessoryView, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 40)])
    
    
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    @objc func keyboardWillShow(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else {
            return
        }
        guard let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber else {
            return
        }
        guard let curve = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber else {
            return
        }
        
        let keyboardRectangle = keyboardFrame.cgRectValue
        let keyboardHeight = keyboardRectangle.height
        accessoryViewBottom.constant = -keyboardHeight
        UIView.animate(withDuration: TimeInterval(duration.doubleValue), delay: 0, options: UIView.AnimationOptions(rawValue: UInt(curve.intValue)), animations: {
            self.view.layoutIfNeeded()
        }, completion: nil)
    }
    
    @objc func keyboardWillHide(_ notification: Notification) {
        accessoryViewBottom.constant = 40
    }
    
    @objc func dismissKeyboard(_ sender: UIButton) {
        nicknameField.resignFirstResponder()
        textView.resignFirstResponder()
    }
    
    @IBAction func cancelTapped(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func pasteAction(_ sender: UIButton) {
        textView.text = UIPasteboard.general.string
    }
    
    @IBAction func openFilesApp(_ sender: UIButton!) {
        let documentVC = DocumentBrowserViewController()
        documentVC.browserViewController.delegate = self
        self.present(documentVC, animated: true, completion: nil)
    }
    
    @IBAction func importWalletKeys(_ sender: UIButton!) {
        let data = textView.text.data(using: .utf8)
        guard let encrypted = data, encrypted.count > 0 else {
            self.showAlert(title: "", message: "You must input content of your wallet file")
            return
        }
        guard let nickname = nicknameField.text, nickname.count > 0 else {
            self.showAlert(title: "", message: "You must have at least one character for your key name")
            return
        }
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let decoded = try decoder.decode(CipherData.self, from: encrypted).cipherKeys
            
            let pwdAlert = UIAlertController(title: nil, message: "Input unlock password", preferredStyle: .alert)
            let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
            let submit = UIAlertAction(title: "Submit", style: .default) { [weak self] _ in
                guard let password = pwdAlert.textFields?.first?.text, password.count > 0 else {
                    self?.showAlert(title: "", message: "You must input unlock password")
                    return
                }
                self?.unlockWallet(cipher: decoded, password: password, name: nickname)
            }
            pwdAlert.addAction(submit)
            pwdAlert.addAction(cancel)
            pwdAlert.addTextField { textField in
                textField.isSecureTextEntry = true
            }
            self.present(pwdAlert, animated: true, completion: nil)
        } catch {
            self.showAlert(title: "", message: error.localizedDescription)
        }
    }
    
    func unlockWallet(cipher: String, password: String, name: String) {
        do {
            let wallet = try Wallet(cipherText: cipher)
            let keys = try wallet.unlock(password: password)
            
            for object in keys.enumerated() {
                let suffix = keys.count == 1 ? "" : "-key-\((object.offset + 1))"
                
                let privateKey: String
                switch object.element.pri.curve {
                case .k1:
                    privateKey = object.element.pri.bytes.toEosioK1PrivateKey
                case .r1:
                    privateKey = object.element.pri.bytes.toEosioR1PrivateKey
                }
                
                try importKey(privateKey, name: name + suffix)
            }
        } catch {
            self.showAlert(title: "", message: error.localizedDescription)
        }
    }
}

struct CipherData: Codable {
    let cipherKeys: String
}

extension ImportWalletViewController: UIDocumentBrowserViewControllerDelegate {
    func documentBrowser(_ controller: UIDocumentBrowserViewController, didPickDocumentsAt documentURLs: [URL]) {
        guard let url = documentURLs.first else {
            return
        }
        guard url.startAccessingSecurityScopedResource() else {
            return
        }
        
        NSFileCoordinator().coordinate(readingItemAt: url, options: .withoutChanges, error: nil) { [weak self] authUrl in
            do {
                let text = try String(contentsOf: authUrl)
                self?.textView.text = text
                controller.dismiss(animated: true, completion: nil)
            } catch {
                controller.showAlert(title: "", message: error.localizedDescription)
            }
        }
    }
}
