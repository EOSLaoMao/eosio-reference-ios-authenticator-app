//
//  AuthorizersListViewController.swift
//  Eosio
//
//  Created by Serguei Vinnitskii on 11/14/18.
//  Copyright (c) 2017-2019 block.one and its contributors. All rights reserved.
//

import UIKit
import EosioSwift
import EosioSwiftVault
import LocalAuthentication

class AuthorizersListViewController: UIViewController {

    
    @IBOutlet weak var tableView: UITableView!
    var showHelperText = true
    let helperTextIndexPath = IndexPath(row: 0, section: 0)

    // model
    var keychainKeys: [Device.Key]?
    //var keychainMetaKeys: [EosioVault.KeyMetadata]?
    var keys: [EosioVault.VaultKey]?
    private let vault = EosioVault(accessGroup: Constants.vaultAccessGroup)

    override func viewDidLoad() {
        super.viewDidLoad()
                
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 0)) //empty footer to remove un-used cells
        
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 100
        
        self.showHelperText = !UserDefaults.Eosio.bool(forKey: .autorizersHelperTextHasBeenShown , defaultValue: false)
        updateDataSourceWithCurrentKeys()
        
        let rightButton = UIButton(type: .custom)
        let gearImage = UIImage(named: "settingsGear")?.withRenderingMode(.alwaysTemplate) ?? UIImage()
        rightButton.setImage(gearImage, for: .normal)
        rightButton.frame = CGRect(x: 0.0, y: 0.0, width: 90.0, height: 44.0)
        rightButton.tintColor = UIColor.customDarkBlue
        let rightMargin = CGFloat(10)
        let leftMargin = rightButton.frame.width - (gearImage.size.width + rightMargin)
        rightButton.imageEdgeInsets = UIEdgeInsets(top: 7, left: leftMargin, bottom: 7, right: rightMargin)
        rightButton.addTarget(self, action: #selector(settingsPressed), for: .touchUpInside)
        
        let rightBarButtonItem = UIBarButtonItem(customView: rightButton)
        self.navigationItem.rightBarButtonItem = rightBarButtonItem
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: UIBarButtonItem.Style.plain, target: nil, action: nil)
        
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.isHidden = false
        self.navigationController?.navigationBar.prefersLargeTitles = true
        updateDataSourceWithCurrentKeys()
        tableView.reloadData()
        
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        NotificationCenter.default.addObserver(forName: ImportKeyTableViewController.importKeySucceedNotification, object: nil, queue: OperationQueue.main) { [weak self] _ in
            self?.updateDataSourceWithCurrentKeys()
            self?.tableView.reloadData()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }

    private func updateDataSourceWithCurrentKeys() {
        let device = Device.current
        keychainKeys = device.keys
        guard let validKeysArray = try? vault.getAllVaultKeys() else { return }
        let sortedSecureEnclaveKeys = validKeysArray.filter({$0.isSecureEnclave == true}).sorted{$0.name < $1.name}
        let sortedSoftKeys = validKeysArray.filter({$0.isSoftKey == true}).sorted{$0.name < $1.name}
        keys = sortedSecureEnclaveKeys + sortedSoftKeys
    }
    
    @objc func settingsPressed(sender: UIButton!) {
        
        let vc = UIStoryboard(name: "Settings", bundle: nil).instantiateViewController(withIdentifier: "settingsVC") as! SettingsViewController
        self.navigationController?.pushViewController(vc, animated: true)
        
    }
    
    @IBAction func addAdditionalAuthenticator(sender: UIButton!) {
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        let fromWalletAction = UIAlertAction(title: "import from wallet file", style: .default) { [unowned self] _ in
            self.performSegue(withIdentifier: "FromWalletSegue", sender: nil)
        }
        let fromManually = UIAlertAction(title: "manually input the private key", style: .default) { [unowned self] _ in
            self.performSegue(withIdentifier: "FromManualSegue", sender: nil)
        }
        let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alertController.addAction(fromWalletAction)
        alertController.addAction(fromManually)
        alertController.addAction(cancel)
        self.present(alertController, animated: true, completion: nil)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {
        case "showKeyDetails":
            guard let authenticatorVC = segue.destination as? AuthenticatorDetailsTableViewController else { return }
            guard let validIndexPath = tableView.indexPathForSelectedRow else { return }
            guard let key = keys?[validIndexPath.row] else { return }
            guard key.isEnabled == true else { return }
            authenticatorVC.key = key
        default: break // do nothing
        }
    }

    private func showHelperTextRow() {
        self.showHelperText = true
        self.tableView.reloadSections(IndexSet(integer: 0), with: .automatic)
    }

    private func hideHelperTextRow() {
        self.showHelperText = false; UserDefaults.Eosio.set(true, forKey: .autorizersHelperTextHasBeenShown)
        self.tableView.reloadSections(IndexSet(integer: 0), with: .automatic)
    }
}

// MARK: - Table View Delegate Methods
extension AuthorizersListViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {
        return 2 // Section 1: helper text. Section 2: authorizers
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? 1 : (keys?.count ?? 0)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        switch indexPath.section {
        case 0:
            var cell = UITableViewCell()
            if showHelperText == true {
                cell = tableView.dequeueReusableCell(withIdentifier: "HelperTextCell") as! AuthorizersListHelperTextCell
            } else {
                cell = tableView.dequeueReusableCell(withIdentifier: "showHelpCell") ?? UITableViewCell()
            }
            cell.selectionStyle = .none
            return cell
        case 1:
            let currentKey = keys?[indexPath.row]
            if currentKey?.isEnabled == true {
                // active
                let cell = tableView.dequeueReusableCell(withIdentifier: "DeviceCell") as! AuthorizersListDeviceCell
                cell.setupCell(withKey: currentKey)
                return cell
            } else {
                // marked "Deleted"
                let cell = tableView.dequeueReusableCell(withIdentifier: "DeletedAuthCell") as! UndoDeletedKeyCell
                cell.setupCell(withKey: currentKey)
                return cell
            }
        default:
            return UITableViewCell()
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        switch indexPath.section {
        case 0:
            // helper text section
            if showHelperText == true {
                hideHelperTextRow() }
            else {
                showHelperTextRow()
            }
        default:
           return
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

}
