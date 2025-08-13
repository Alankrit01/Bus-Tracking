//
//  MenuViewController.swift
//  Merseyside_bus
//
//  Created by Shivansh Raj on 30/03/2025.
//

import UIKit

class MenuViewController: UIViewController {

    @IBAction func startJourneyButton(_ sender: Any) {
        performSegue(withIdentifier: "toMap", sender: nil)
    }
    @IBOutlet weak var menuLabel: UILabel!
    @IBOutlet weak var startJourneyButton: UIButton!
    
    @IBAction func topUpButton(_ sender: Any) {
        performSegue(withIdentifier: "toTopUp", sender: nil)
    }
    
    @IBAction func contactUsButton(_ sender: Any) {
        performSegue(withIdentifier: "toContactUs", sender: nil)
    }
    @IBAction func myScheduleButton(_ sender: Any) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
            if let myScheduleVC = storyboard.instantiateViewController(withIdentifier: "MyScheduleViewController") as? MyScheduleViewController {
                self.navigationController?.pushViewController(myScheduleVC, animated: true)
            }
        
    }
    
    @IBAction func contactlessButton(_ sender: Any) {
        performSegue(withIdentifier: "toBusCard", sender: nil)
    }
    


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
