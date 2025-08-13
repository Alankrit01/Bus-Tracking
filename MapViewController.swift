//
//  MapViewController.swift
//  Merseyside_bus
//
//

import UIKit
import MapKit
import CoreLocation
import FirebaseAuth
import FirebaseFirestore

class MapViewController: UIViewController, CLLocationManagerDelegate, UITableViewDataSource, UITableViewDelegate, MKMapViewDelegate {

    @IBOutlet weak var startTF: UITextField!
    @IBOutlet weak var endTF: UITextField!
    @IBOutlet weak var myMap: MKMapView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var startJourneyButton: UIButton!
    @IBOutlet weak var resetButton: UIButton!

    @IBAction func backButton(_ sender: Any) {
        performSegue(withIdentifier: "toMenu", sender: nil)
    }
    
    @IBOutlet weak var currentImage: UIImageView!
    
    @IBOutlet weak var transferImage: UIImageView!
    @IBOutlet weak var destinationImage: UIImageView!
    
    var routes: [(name: String, stops: [BusStop])] = []
    var expandedIndexSet: Set<Int> = []
    var highlightedRouteIndex: Int? = nil
    
    var busAnnotation: MKPointAnnotation? = nil
    var busTimer: Timer?
    var busPathCoordinates: [CLLocationCoordinate2D] = []
    var currentBusIndex: Int = 0
    
    // Properties for stop suggestions
    var allStopNames: [String] = []
    var filteredStartStops: [String] = []
    var filteredEndStops: [String] = []
    var suggestionsTableView: UITableView?
    var activeTextField: UITextField?
    
    // Track if a journey is in progress
    var isJourneyActive = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        myMap.delegate = self
        tableView.dataSource = self
        tableView.delegate = self
        startJourneyButton.isHidden = true // Hide until route found
        resetButton.isHidden = true // Initially hide reset button
        
        // Setup text fields for autocomplete
        startTF.delegate = self
        endTF.delegate = self
        setupSuggestionsTableView()
        
        loadBusData()
    }
    
    func loadBusData() {
        if let url = Bundle.main.url(forResource: "BusStopsSuper", withExtension: "json") {
            do {
                let data = try Data(contentsOf: url)
                let decodedData = try JSONDecoder().decode(SuperBusData.self, from: data)
                
                for (routeName, superRoute) in decodedData.routes {
                    routes.append((name: routeName, stops: superRoute.stops))
                }
                
                self.tableView.reloadData()
                
                // Extract all unique stop names after loading routes
                var stopNameSet = Set<String>()
                for route in routes {
                    for stop in route.stops {
                        stopNameSet.insert(stop.stop_name)
                    }
                }
                allStopNames = Array(stopNameSet).sorted()
            } catch {
                print("Error decoding JSON: \(error)")
            }
        } else {
            print("BusStopsSuper.json file not found")
        }
    }
    
    func setupSuggestionsTableView() {
        // Create suggestions table view
        suggestionsTableView = UITableView()
        suggestionsTableView?.delegate = self
        suggestionsTableView?.dataSource = self
        suggestionsTableView?.register(UITableViewCell.self, forCellReuseIdentifier: "SuggestionCell")
        suggestionsTableView?.isHidden = true
        suggestionsTableView?.layer.borderWidth = 1
        suggestionsTableView?.layer.borderColor = UIColor.lightGray.cgColor
        suggestionsTableView?.layer.cornerRadius = 5
        
        if let suggestionsTableView = suggestionsTableView {
            view.addSubview(suggestionsTableView)
        }
    }
    
    @IBAction func goButton(_ sender: Any) {
        // If there's a journey in progress, reset first
        if isJourneyActive {
            resetJourney()
        }
        
        view.endEditing(true)
        findBestRoute()
    }
    
    @IBAction func resetButtonPressed(_ sender: Any) {
        resetJourney()
    }
    
    func resetJourney() {
        // Set journey inactive before stopping timer to prevent completion message
        isJourneyActive = false
        
        // Stop any ongoing animation
        busTimer?.invalidate()
        busTimer = nil
        
        // Remove bus and overlays
        if let busAnnotation = busAnnotation {
            myMap.removeAnnotation(busAnnotation)
            self.busAnnotation = nil
        }
        
        myMap.removeOverlays(myMap.overlays)
        
        // Remove stop annotations, keeping other annotations if any
        let annotations = myMap.annotations.filter {
            !($0 is MKUserLocation) && $0 !== busAnnotation
        }
        myMap.removeAnnotations(annotations)
        
        // Reset UI state
        startJourneyButton.isHidden = true
        resetButton.isHidden = true
        
        // Clear route selection
        highlightedRouteIndex = nil
        busPathCoordinates = []
        currentBusIndex = 0
        
        // Refresh table
        tableView.reloadData()
    }
    
    func findBestRoute() {
        guard let startText = startTF.text, !startText.isEmpty,
              let endText = endTF.text, !endText.isEmpty else {
            showAlert(title: "Missing Information", message: "Please enter both start and end stops.")
            return
        }
        
        // Clear previous highlights
        highlightedRouteIndex = nil
        myMap.removeAnnotations(myMap.annotations.filter { !($0 is MKUserLocation) })
        myMap.removeOverlays(myMap.overlays)
        
        var foundRoute = false
        var bestRouteIndex: Int?
        var bestRouteStops: [BusStop]?
        var minStops = Int.max
        
        // Search all routes for matches (case insensitive)
        for (index, route) in routes.enumerated() {
            let stopNames = route.stops.map { $0.stop_name.lowercased() }
            
            // Find start and end stops with partial matching
            if let startIndex = stopNames.firstIndex(where: { $0.contains(startText.lowercased()) }),
               let endIndex = stopNames.firstIndex(where: { $0.contains(endText.lowercased()) }),
               startIndex < endIndex {
                
                foundRoute = true
                let stopCount = endIndex - startIndex
                
                // Keep track of the route with fewest stops
                if stopCount < minStops {
                    minStops = stopCount
                    bestRouteIndex = index
                    bestRouteStops = Array(route.stops[startIndex...endIndex])
                }
            }
        }
        
        if foundRoute, let index = bestRouteIndex, let stops = bestRouteStops {
            highlightedRouteIndex = index
            drawRouteOnMap(stops: stops)
            startJourneyButton.isHidden = false
        } else {
            showAlert(title: "No Route Found",
                     message: "Could not find a route between these stops. Please check your entries.")
        }
        
        tableView.reloadData()
    }
    
    func showAlert(title: String, message: String) {
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    func drawRouteOnMap(stops: [BusStop]) {
        // Clear previous routes and annotations
        myMap.removeAnnotations(myMap.annotations.filter { !($0 is MKUserLocation) })
        myMap.removeOverlays(myMap.overlays)
        
        // Reset path coordinates to avoid issues with previous routes
        busPathCoordinates = []
        
        // Add stop annotations
        for stop in stops {
            let coordinate = CLLocationCoordinate2D(latitude: stop.latitude, longitude: stop.longitude)
            
            let annotation = MKPointAnnotation()
            annotation.coordinate = coordinate
            annotation.title = stop.stop_name
            myMap.addAnnotation(annotation)
        }
        
        // Request directions between consecutive stops
        if stops.count >= 2 {
            let group = DispatchGroup()
            var allSegments: [(Int, [CLLocationCoordinate2D])] = []
            
            for i in 0..<(stops.count - 1) {
                group.enter()
                
                let sourceCoordinate = CLLocationCoordinate2D(latitude: stops[i].latitude, longitude: stops[i].longitude)
                let destinationCoordinate = CLLocationCoordinate2D(latitude: stops[i+1].latitude, longitude: stops[i+1].longitude)
                
                let sourcePlacemark = MKPlacemark(coordinate: sourceCoordinate)
                let destinationPlacemark = MKPlacemark(coordinate: destinationCoordinate)
                
                let sourceMapItem = MKMapItem(placemark: sourcePlacemark)
                let destinationMapItem = MKMapItem(placemark: destinationPlacemark)
                
                let directionRequest = MKDirections.Request()
                directionRequest.source = sourceMapItem
                directionRequest.destination = destinationMapItem
                directionRequest.transportType = .automobile
                
                let directions = MKDirections(request: directionRequest)
                directions.calculate { [weak self] (response, error) in
                    guard let self = self else {
                        group.leave()
                        return
                    }
                    
                    defer { group.leave() }
                    
                    if let error = error {
                        print("Error calculating directions: \(error.localizedDescription)")
                        // Fallback to straight line
                        let polyline = MKPolyline(coordinates: [sourceCoordinate, destinationCoordinate], count: 2)
                        self.myMap.addOverlay(polyline)
                        
                        
                        allSegments.append((i, [sourceCoordinate, destinationCoordinate]))
                        
                    } else if let response = response, let route = response.routes.first {
                        // Add route to map
                        self.myMap.addOverlay(route.polyline)
                        
                        // Get coordinates from polyline
                        let routeCoordinates = self.getCoordinatesFromPolyline(route.polyline)
                        
                        // Add this segment with index
                        allSegments.append((i, routeCoordinates))
                    }
                }
            }
            
            // Process all segments in the correct order once completed
            group.notify(queue: .main) { [weak self] in
                guard let self = self else { return }
                
                // Sort segments by index
                allSegments.sort { $0.0 < $1.0 }
                
                // Combine all coordinates in order
                var orderedCoordinates: [CLLocationCoordinate2D] = []
                
                for (i, coordinates) in allSegments {
                    if i == 0 {
                        // Include all coordinates from first segment
                        orderedCoordinates.append(contentsOf: coordinates)
                    } else {
                        // Skip first coordinate of subsequent segments
                        if coordinates.count > 1 {
                            orderedCoordinates.append(contentsOf: coordinates.dropFirst())
                        }
                    }
                }
                
                self.busPathCoordinates = orderedCoordinates
                self.currentBusIndex = 0
            }
        }
        
        // Center map on first stop
        if let first = stops.first {
            let region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: first.latitude, longitude: first.longitude), latitudinalMeters: 3000, longitudinalMeters: 3000)
            myMap.setRegion(region, animated: true)
        }
    }
    
    func getCoordinatesFromPolyline(_ polyline: MKPolyline) -> [CLLocationCoordinate2D] {
        var coordinates = [CLLocationCoordinate2D](repeating: CLLocationCoordinate2D(), count: polyline.pointCount)
        polyline.getCoordinates(&coordinates, range: NSRange(location: 0, length: polyline.pointCount))
        return coordinates
    }
    
    @IBAction func zoomOutPressed(_ sender: Any) {
        var region = myMap.region
            region.span.latitudeDelta *= 2
            region.span.longitudeDelta *= 2
            myMap.setRegion(region, animated: true)
    }
    
    @IBAction func zoomInPressed(_ sender: Any) {
        var region = myMap.region
            region.span.latitudeDelta /= 2
            region.span.longitudeDelta /= 2
            myMap.setRegion(region, animated: true)
        
    }
    
    @IBAction func startJourneyPressed(_ sender: Any) {
        if isJourneyActive {
            resetJourney()
        }
        startBusSimulation()
    }
    
    func startBusSimulation() {
        // Clear any existing timer
        busTimer?.invalidate()
        busTimer = nil
        
        // Remove old bus annotation if it exists
        if let busAnnotation = busAnnotation {
            myMap.removeAnnotation(busAnnotation)
        }
        
        // Ensure we have coordinates
        guard !busPathCoordinates.isEmpty else {
            print("No coordinates for bus animation")
            return
        }
        
        // Create new bus annotation at the FIRST stop
        let newBusAnnotation = MKPointAnnotation()
        newBusAnnotation.coordinate = busPathCoordinates[0]
        newBusAnnotation.title = "Bus"
        busAnnotation = newBusAnnotation
        myMap.addAnnotation(newBusAnnotation)
        
        // Reset index to 1 (we're already at position 0)
        currentBusIndex = 1
        
        // Set journey as active
        isJourneyActive = true
        
        // Show reset button
        resetButton.isHidden = false
        
        // Start the timer
        busTimer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(moveBus), userInfo: nil, repeats: false)
        
        // Center map on bus starting point
        let region = MKCoordinateRegion(center: busPathCoordinates[0], latitudinalMeters: 1000, longitudinalMeters: 1000)
        myMap.setRegion(region, animated: true)
    }
    
    @objc func moveBus() {
        // Cancel any existing timer
        busTimer?.invalidate()
        busTimer = nil
        
        // Check if we've reached the end of the route
        guard currentBusIndex < busPathCoordinates.count else {
            if isJourneyActive {
                isJourneyActive = false
                
                let alert = UIAlertController(
                    title: "Journey Complete",
                    message: "You have arrived at your destination.",
                    preferredStyle: .alert
                )
                
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                    // Save the completed journey when user taps OK
                    self.saveJourneyToHistory(startStop: self.startTF.text ?? "", endStop: self.endTF.text ?? "")
                }))
                
                present(alert, animated: true)
            }
            return
        }

        
        let nextCoord = busPathCoordinates[currentBusIndex]
        
        // Calculate animation duration
        var animationDuration = 0.4
        
        if currentBusIndex > 0 {
            let prevCoord = busPathCoordinates[currentBusIndex - 1]
            let prevLocation = CLLocation(latitude: prevCoord.latitude, longitude: prevCoord.longitude)
            let nextLocation = CLLocation(latitude: nextCoord.latitude, longitude: nextCoord.longitude)
            
            let distance = prevLocation.distance(from: nextLocation)
            // Scale duration based on distance
            animationDuration = min(max(distance / 80.0, 0.3), 1.0) * 0.65
        }
        
        // Update bus annotation position with calculated duration
        UIView.animate(withDuration: animationDuration, animations: {
            self.busAnnotation?.coordinate = nextCoord
        }, completion: { _ in
            let currentBusCoordinate = nextCoord

            for route in self.routes {
                for stop in route.stops {
                    let stopLocation = CLLocation(latitude: stop.latitude, longitude: stop.longitude)
                    let busLocation = CLLocation(latitude: currentBusCoordinate.latitude, longitude: currentBusCoordinate.longitude)
                    let distance = busLocation.distance(from: stopLocation)

                    if distance < 100 { // meters
                        self.showArrivalPopup(at: stopLocation.coordinate, text: stop.stop_name)
                    }
                }
            }

            // Only proceed if journey is still active
            if self.isJourneyActive {
                self.currentBusIndex += 1
                
                // Schedule the next movement
                self.busTimer = Timer.scheduledTimer(
                    timeInterval: 0.1,  // Reduced delay between movements
                    target: self,
                    selector: #selector(self.moveBus),
                    userInfo: nil,
                    repeats: false
                )
            }
        })
    }
    
    func saveJourneyToHistory(startStop: String, endStop: String) {
        guard let userEmail = Auth.auth().currentUser?.email else { return }
        
        let db = Firestore.firestore()
        
        let journeyData = [
            "start": startStop,
            "end": endStop,
            "timestamp": Timestamp(date: Date())
        ] as [String : Any]
        
        db.collection("journeyHistory")
            .document(userEmail)
            .collection("journeys")
            .addDocument(data: journeyData) { error in
                if let error = error {
                    print("Error saving journey: \(error.localizedDescription)")
                } else {
                    print("Journey saved successfully!")
                }
        }
    }


    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let polyline = overlay as? MKPolyline {
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = UIColor.systemBlue
            renderer.lineWidth = 4
            return renderer
        }
        return MKOverlayRenderer(overlay: overlay)
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if let popupAnnotation = annotation as? BusStopPopupAnnotation {
            let identifier = "PopupAnnotation"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)

            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = false

                let label = UILabel()
                label.text = popupAnnotation.title
                label.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.9)
                label.textColor = .white
                label.font = UIFont.boldSystemFont(ofSize: 14)
                label.textAlignment = .center
                label.layer.cornerRadius = 8
                label.layer.masksToBounds = true
                label.frame = CGRect(x: 0, y: 0, width: 150, height: 30)

                annotationView?.addSubview(label)
                annotationView?.frame = label.frame
            } else {
                annotationView?.annotation = annotation
            }

            return annotationView
        }

        if annotation === busAnnotation {
            let identifier = "BusAnnotation"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)

            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = false
                annotationView?.image = UIImage(named: "busIcon") ?? UIImage(systemName: "bus") // 🚌 custom bus icon
            } else {
                annotationView?.annotation = annotation
            }
            
            return annotationView
        }

        let identifier = "StopMarker"
        var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)

        if annotationView == nil {
            annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            annotationView?.canShowCallout = true
        } else {
            annotationView?.annotation = annotation
        }

        // Customize the stop marker (small red dot)
        let dotSize: CGFloat = 8.0
        let dotView = UIView(frame: CGRect(x: 0, y: 0, width: dotSize, height: dotSize))
        dotView.backgroundColor = UIColor.red
        dotView.layer.cornerRadius = dotSize / 2

        UIGraphicsBeginImageContextWithOptions(dotView.bounds.size, false, 0)
        if let context = UIGraphicsGetCurrentContext() {
            dotView.layer.render(in: context)
            let dotImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            annotationView?.image = dotImage
        }

        return annotationView
    }

    // MARK: - UITableViewDelegate and UITableViewDataSource
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView == suggestionsTableView {
            if activeTextField == startTF {
                return filteredStartStops.count
            } else if activeTextField == endTF {
                return filteredEndStops.count
            }
            return 0
        }
        
        // For main route table view
        return routes.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if tableView == suggestionsTableView {
            let cell = tableView.dequeueReusableCell(withIdentifier: "SuggestionCell", for: indexPath)
            
            if activeTextField == startTF && indexPath.row < filteredStartStops.count {
                cell.textLabel?.text = filteredStartStops[indexPath.row]
            } else if activeTextField == endTF && indexPath.row < filteredEndStops.count {
                cell.textLabel?.text = filteredEndStops[indexPath.row]
            }
            
            return cell
        }
        
        // For main routes table
        let cell = tableView.dequeueReusableCell(withIdentifier: "myCell", for: indexPath)
        let route = routes[indexPath.row]
        
        let attributedText = NSMutableAttributedString()
        let isExpanded = expandedIndexSet.contains(indexPath.row)
        let expandIcon = isExpanded ? "➖" : "➕"
        
        let routeTitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 18)
        ]
        let title = NSAttributedString(string: "\(expandIcon) \(route.name)\n", attributes: routeTitleAttributes)
        attributedText.append(title)
        
        if isExpanded {
            let stopAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16)
            ]
            for stop in route.stops {
                let stopLine = NSAttributedString(string: "   • \(stop.stop_name)\n", attributes: stopAttributes)
                attributedText.append(stopLine)
            }
        }
        
        cell.textLabel?.numberOfLines = 0
        cell.textLabel?.attributedText = attributedText
        cell.backgroundColor = (highlightedRouteIndex == indexPath.row) ? UIColor.systemBlue.withAlphaComponent(0.3) : UIColor.clear
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView == suggestionsTableView {
            if activeTextField == startTF && indexPath.row < filteredStartStops.count {
                startTF.text = filteredStartStops[indexPath.row]
            } else if activeTextField == endTF && indexPath.row < filteredEndStops.count {
                endTF.text = filteredEndStops[indexPath.row]
            }
            
            // Hide suggestions after selection
            suggestionsTableView?.isHidden = true
            activeTextField?.resignFirstResponder()
            
        } else {
            // For main routes table
            tableView.deselectRow(at: indexPath, animated: true)
            
            if expandedIndexSet.contains(indexPath.row) {
                expandedIndexSet.remove(indexPath.row)
            } else {
                expandedIndexSet.insert(indexPath.row)
            }
            
            tableView.reloadRows(at: [indexPath], with: .automatic)
        }
    }
}

// MARK: - UITextFieldDelegate
extension MapViewController: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        activeTextField = textField
        
        // Position suggestions table view under the active text field
        positionSuggestionsTableView(under: textField)
        
        // Filter stops initially based on current text
        filterStops(for: textField.text ?? "")
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if let text = textField.text, let textRange = Range(range, in: text) {
            let updatedText = text.replacingCharacters(in: textRange, with: string)
            filterStops(for: updatedText)
        }
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        // Hide suggestions after a delay to allow selection
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.suggestionsTableView?.isHidden = true
        }
    }
    
    func filterStops(for searchText: String) {
        // Case-insensitive filtering
        let filtered = allStopNames.filter { $0.lowercased().contains(searchText.lowercased()) }
        
        if activeTextField == startTF {
            filteredStartStops = filtered
        } else if activeTextField == endTF {
            filteredEndStops = filtered
        }
        
        // Show/hide suggestions based on filter results and visibility
        if (activeTextField == startTF && !filteredStartStops.isEmpty) ||
           (activeTextField == endTF && !filteredEndStops.isEmpty) {
            suggestionsTableView?.reloadData()
            suggestionsTableView?.isHidden = false
        } else {
            suggestionsTableView?.isHidden = true
        }
    }
    func showArrivalPopup(at coordinate: CLLocationCoordinate2D, text: String) {
        let popupAnnotation = BusStopPopupAnnotation(coordinate: coordinate, title: text)
        myMap.addAnnotation(popupAnnotation)

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.myMap.removeAnnotation(popupAnnotation)
        }
    }
    
    func positionSuggestionsTableView(under textField: UITextField) {
        guard let suggestionsTableView = suggestionsTableView else { return }
        
        let textFieldFrame = textField.convert(textField.bounds, to: view)
        let suggestionsHeight = min(CGFloat(5 * 44), CGFloat(200)) // Max 5 rows or 200pt
        
        suggestionsTableView.frame = CGRect(
            x: textFieldFrame.minX,
            y: textFieldFrame.maxY + 5,
            width: textFieldFrame.width,
            height: suggestionsHeight
        )
        
        view.bringSubviewToFront(suggestionsTableView)
    }
}


class BusStopPopupAnnotation: NSObject, MKAnnotation {
    var coordinate: CLLocationCoordinate2D
    var title: String?

    init(coordinate: CLLocationCoordinate2D, title: String?) {
        self.coordinate = coordinate
        self.title = title
    }
}
