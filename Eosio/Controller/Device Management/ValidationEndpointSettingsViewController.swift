//
//  ValidationEndpointSettingsViewController.swift
//  EosioReferenceAuthenticator

//  Created by iCell on 2019/6/20
//  Copyright (c) 2017-2019 block.one and its contributors. All rights reserved.
//


import UIKit

class ValidationEndpointSettingsViewController: UIViewController {

    public static let validationDomainKey = "ValidationDomainKey"
    
    @IBOutlet weak var textField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        textField.text = ValidationEndpointSettingsViewController.validationDomain
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        view.endEditing(true)
    }
    
    public static var validationDomain: String {
        let domain = UserDefaults.standard.string(forKey: validationDomainKey)
        if let domain = domain {
            return domain
        }
        return "https://api-kylin.eoslaomao.com"
    }

}
