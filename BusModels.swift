//
//  BusModels.swift
//  Merseyside_bus
//
//  Created by Shivansh Raj on 26/04/2025.
//

import Foundation

struct SuperBusData: Codable {
    var routes: [String: SuperRoute]
}

struct SuperRoute: Codable {
    var stops: [BusStop]
}

struct BusStop: Codable {
    var stop_name: String
    var lat: Double
    var lng: Double
    var times: [String]
    
    var latitude: Double { lat }
    var longitude: Double { lng }
}


