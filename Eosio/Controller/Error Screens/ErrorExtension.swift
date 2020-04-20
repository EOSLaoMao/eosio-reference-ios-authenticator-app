//
//  ErrorExtension.swift
//  EosioReferenceAuthenticator

//  Created by Shawn Lee on 2020/4/20
//  Copyright (c) 2017-2020 block.one and its contributors. All rights reserved.
//


import UIKit

extension UIViewController {
    func showAlert(title: String, message: String?) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
}
