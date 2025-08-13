//
//  ContactUsViewController.swift
//  Merseyside_bus
//
//  Created by Shivansh Raj on 29/04/2025.
//

import UIKit

class ContactUsViewController: UIViewController {

    @IBAction func goBackButton(_ sender: Any) {
        performSegue(withIdentifier: "toMenu", sender: nil)
    }
    
    @IBOutlet weak var headingLabel: UILabel!
    
    @IBOutlet weak var descriptionLabel: UILabel!
    
    @IBOutlet weak var textLabel: UILabel!
    @IBOutlet weak var numberLabel: UILabel!
    @IBOutlet weak var emailLabel: UILabel!
    @IBOutlet weak var callLabel: UILabel!
    @IBOutlet weak var emailImage: UIImageView!
    @IBOutlet weak var callImage: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
