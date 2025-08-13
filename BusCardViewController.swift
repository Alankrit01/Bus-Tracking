//
//  BusCardViewController.swift
//  Merseyside_bus
//
//  Created by Shivansh Raj on 27/04/2025.
//

import UIKit

class BusCardViewController: UIViewController {

    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var contactlessImageView: UIImageView!
    @IBOutlet weak var logoImageView: UIImageView!
    @IBOutlet weak var cardNumberLabel: UILabel!
    
    @IBOutlet weak var readerLabel: UILabel!
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupTapToDismiss()

        
    }
    override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            animateCardPopup()
            
            // Auto dismiss after 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                self.dismiss(animated: true, completion: nil)
            }
        }
    
    func setupUI() {
        view.backgroundColor = UIColor.white
        
        
        cardView.layer.cornerRadius = 20
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.2
        cardView.layer.shadowOffset = CGSize(width: 0, height: 5)
        cardView.layer.shadowRadius = 10
        
        contactlessImageView.image = UIImage(systemName: "wave.3.right")
        contactlessImageView.tintColor = .systemBlue
    }
    
    func animateCardPopup() {
            cardView.transform = CGAffineTransform(translationX: 0, y: self.view.frame.height)
            UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: [], animations: {
                self.cardView.transform = .identity
            }, completion: nil)
        }
    
    func setupTapToDismiss() {
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissSelf))
            view.addGestureRecognizer(tapGesture)
        }
    
    @objc func dismissSelf() {
            dismiss(animated: true, completion: nil)
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
