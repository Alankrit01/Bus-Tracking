//
//  TopUpViewController.swift
//  Merseyside_bus
//
//  Created by Shivansh Raj on 28/04/2025.
//

import UIKit

class TopUpViewController: UIViewController {
    
    @IBOutlet weak var topUpLabel: UILabel!
    
    @IBOutlet weak var card3Label: UILabel!
    @IBOutlet weak var card1Label: UILabel!
    @IBOutlet weak var card4Label: UILabel!
    @IBOutlet weak var card2Label: UILabel!
    @IBOutlet weak var Y1Label: UILabel!
    @IBOutlet weak var Y4Label: UILabel!
    @IBOutlet weak var A1Label: UILabel!
    @IBOutlet weak var A4Label: UILabel!
    @IBOutlet weak var ElevenLabel: UILabel!
    @IBOutlet weak var threeEightLabel: UILabel!
    @IBOutlet weak var sevenSevenLabel: UILabel!
    @IBOutlet weak var twoTwoLabel: UILabel!
    
    @IBAction func backButton(_ sender: Any) {
        performSegue(withIdentifier: "toMenu", sender: nil)
    }
    
    @IBAction func buy1Button(_ sender: Any) {
        performSegue(withIdentifier: "toBusCard", sender: nil)
    }
    @IBAction func buy2Button(_ sender: Any) {
        performSegue(withIdentifier: "toBusCard", sender: nil)
    }
    @IBAction func buy3Button(_ sender: Any) {
        performSegue(withIdentifier: "toBusCard", sender: nil)
    }
    @IBAction func buy4Button(_ sender: Any) {
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
