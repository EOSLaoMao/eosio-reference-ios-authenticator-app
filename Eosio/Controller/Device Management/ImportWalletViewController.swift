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

class ImportWalletViewController: UIViewController, ImportKey {
    
    let vault: EosioVault = EosioVault(accessGroup: Constants.vaultAccessGroup)
    
    @IBOutlet var textView: UITextView!
    @IBOutlet var openFileBtn: UIButton!
    
    @IBAction func cancelTapped(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func openFilesApp(_ sender: UIButton!) {
        let documentVC = UIDocumentBrowserViewController(forOpeningFilesWithContentTypes: ["jp.laomao.authenticator"])
        documentVC.allowsDocumentCreation = false
        documentVC.allowsPickingMultipleItems = false
        documentVC.delegate = self
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
                textField.text = "PW5Kf7h86a2WvStSY3f5M6ntdiqqD7a6whvbMrWZMNSMtyrUYD92P"
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
