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
    
    @IBOutlet var textView: UITextView!
    @IBOutlet var openFileBtn: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        textView.layer.borderColor = UIColor.customDarkBlue.cgColor
        textView.layer.borderWidth = 1.0
        textView.layer.cornerRadius = 6.0
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        self.view.endEditing(true)
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
                self?.unlockWallet(cipher: decoded, password: password)
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
    
    func unlockWallet(cipher: String, password: String) {
        do {
            let wallet = try Wallet(cipherText: cipher)
            let keys = try wallet.unlock(password: password)
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd"
            let date = Date()
            let name = dateFormatter.string(from: date)
            
            for key in keys {
                let privateKey: String
                switch key.pri.curve {
                case .k1:
                    privateKey = key.pri.bytes.toEosioK1PrivateKey
                case .r1:
                    privateKey = key.pri.bytes.toEosioR1PrivateKey
                }
                
                try importKey(privateKey, name: name)
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
