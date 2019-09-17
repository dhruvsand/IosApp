//
//  ViewController.swift
//  HeartRatePlotter
//
//  Created by Dhruv Sandesara on 4/18/19.
//  Copyright © 2019 Dhruv Sandesara. All rights reserved.
//

import UIKit
import Charts
import CoreBluetooth

let heartRateServiceCBUUID = CBUUID(string: "180D")
let heartRateMeasurementCharacteristicCBUUID = CBUUID(string: "2A37")
let bodySensorLocationCharacteristicCBUUID = CBUUID(string: "2A38")

class ViewController: UIViewController {
    
    @IBOutlet weak var gifImageView: UIImageView!
    
    @IBOutlet weak var EKGgif: UIImageView!
    
    @IBOutlet weak var condition: UILabel!
    
    
    @IBOutlet weak var heartRateLabel: UILabel!
    var readings = Array(repeating: 0, count: 1000)
    var index = 0
    var centralManager: CBCentralManager!
    var heartRatePeripheral: CBPeripheral!
    var record = false
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let proofOfConceptGif = UIImage.gif(name: "transparentHeart")
        gifImageView.image = proofOfConceptGif
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        centralManager = CBCentralManager(delegate: self, queue: nil)
        
        
        // Make the digits monospaces to avoid shifting when the numbers change
        heartRateLabel.font = UIFont.monospacedDigitSystemFont(ofSize: heartRateLabel.font!.pointSize, weight: .regular)
        // Do any additional setup after loading the view.
        setupChart()
    }
    
    func setupChart(){
        let color = UIColor(red: 250/255, green: 104/255, blue: 104/255, alpha: 1)
        chartView.backgroundColor = color
        chartView.autoScaleMinMaxEnabled = false
    }

    @IBAction func simulateButtonPressed(_ sender: Any) {
        record = !record
//        let jenky = UIImage.gif(name: "ECG2")
//        EKGgif.image = jenky
//        self.readings = [0,1,2,3,4,5,6,7]
//        self.updateChart()
//        condition.text = String("ECG good. High BPM: Maybe Tachycardia")
    }
    
    func onHeartRateReceived(_ heartRate: Int) {
        
        
        if(record){
            heartRateLabel.text = String("BPM: \(heartRate)")
            print("BPM: \(heartRate)")
            self.updateChart()
        }
    }

    
    @IBOutlet weak var chartView: LineChartView!
    
    private func updateChart() {
        
        
        var chartEntry = [ChartDataEntry]()
        for i in 0..<readings.count {
            let value = ChartDataEntry(x: Double(i), y: Double(readings[i]))
            chartEntry.append(value)
        }
        
        let line = LineChartDataSet(values: chartEntry, label: "ECG value")
        line.drawCirclesEnabled = false
        line.colors = [UIColor.green]
        let data = LineChartData()
        data.addDataSet(line)
        chartView.data = data
        
        chartView.chartDescription?.text = "ECG signal"
    }
    
}
extension ViewController: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .unknown:
            print("central.state is .unknown")
        case .resetting:
            print("central.state is .resetting")
        case .unsupported:
            print("central.state is .unsupported")
        case .unauthorized:
            print("central.state is .unauthorized")
        case .poweredOff:
            print("central.state is .poweredOff")
        case .poweredOn:
            print("central.state is .poweredOn")
            centralManager.scanForPeripherals(withServices: [heartRateServiceCBUUID])
            
        @unknown default:
            print("Fatal error")
        }
    }
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print(peripheral)
        heartRatePeripheral = peripheral
        heartRatePeripheral.delegate = self
        
        centralManager.stopScan()
        centralManager.connect(heartRatePeripheral)
        
    }
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected!")
        heartRatePeripheral.discoverServices([heartRateServiceCBUUID])
    }
    
    
}
extension ViewController: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        
        
        guard let services = peripheral.services else { return }
        
        print(services)
        
        for service in services {
            print(service)
            peripheral.discoverCharacteristics(nil, for: service)
            
        }
        
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            print(characteristic)
            if characteristic.properties.contains(.read) {
                print("\(characteristic.uuid): properties contains .read")
                peripheral.readValue(for: characteristic)
                
            }
            if characteristic.properties.contains(.notify) {
                print("\(characteristic.uuid): properties contains .notify")
                peripheral.setNotifyValue(true, for: characteristic)
                
            }
            
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        switch characteristic.uuid {
        case heartRateMeasurementCharacteristicCBUUID:
            print("Found Hearat rate Characteristic")
            let bpm = heartRate(from: characteristic)
            onHeartRateReceived(bpm)
            
            
//        case bodySensorLocationCharacteristicCBUUID:
//            let bodySensorLocation = bodyLocation(from: characteristic)
//            bodySensorLocationLabel.text = bodySensorLocation
        default:
            print("Unhandled Characteristic UUID: \(characteristic.uuid)")
        }
    }
    
    
    
    private func bodyLocation(from characteristic: CBCharacteristic) -> String {
        guard let characteristicData = characteristic.value,
            let byte = characteristicData.first else { return "Error" }
        
        switch byte {
        case 0: return "Other"
        case 1: return "Chest"
        case 2: return "Wrist"
        case 3: return "Finger"
        case 4: return "Hand"
        case 5: return "Ear Lobe"
        case 6: return "Foot"
        default:
            return "Reserved for future use"
        }
    }
    
    private func heartRate(from characteristic: CBCharacteristic) -> Int {
        guard let characteristicData = characteristic.value else { return -1 }
        let byteArray = [UInt8](characteristicData)
//        var current : [Int] = []
        
//        current = [0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19]
        
        for i in 0..<19{
            self.readings[index] = Int(byteArray[i])
            index = (index+1)%1000
        }
//        self.readings = current
       
        return Int(byteArray[19])
}



}
