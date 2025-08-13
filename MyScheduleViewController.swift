//
//  MyScheduleViewController.swift
//  Merseyside_bus
//
//  Created by Shivansh Raj on 28/04/2025.
//

import UIKit
import FirebaseFirestore
import FirebaseAuth

class MyScheduleViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var tableView: UITableView!
    
    @IBAction func backButton(_ sender: Any) {
        performSegue(withIdentifier: "toMenu", sender: nil)
    }
    
    @IBOutlet weak var myScheduleLabel: UILabel!
    
    var journeyHistory: [String] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.delegate = self
        tableView.dataSource = self
        
        tableView.estimatedRowHeight = 100  // Estimate
        tableView.rowHeight = UITableView.automaticDimension
        
        loadJourneyHistory()
    }

    func loadJourneyHistory() {
        guard let userEmail = Auth.auth().currentUser?.email else {
            print("No user email found.")
            return
        }
        
        let db = Firestore.firestore()
        
        db.collection("journeyHistory")
            .document(userEmail)
            .collection("journeys")
            .order(by: "timestamp")
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error loading journeys: \(error.localizedDescription)")
                    return
                }
                
                var journeys: [String] = []
                
                for doc in snapshot?.documents ?? [] {
                    let start = doc.data()["start"] as? String ?? ""
                    let end = doc.data()["end"] as? String ?? ""
                    
                    if !start.isEmpty && !end.isEmpty {
                        journeys.append("\(start) ➔ \(end)")
                    }
                }
                
                self.journeyHistory = journeys
                self.tableView.reloadData()
            }
    }

    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return journeyHistory.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "historyCell", for: indexPath)
        cell.textLabel?.text = journeyHistory[indexPath.row]
        return cell
    }
}

