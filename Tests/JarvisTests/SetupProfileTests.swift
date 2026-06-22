import XCTest
@testable import Jarvis

final class SetupProfileTests: XCTestCase {
    func testBrainMacSelectsAllLocalRoles() {
        XCTAssertEqual(SetupProfile.brainMac.roles, [.brain, .worker, .intercom])
    }

    func testLaptopSelectsIntercomAndWorker() {
        XCTAssertEqual(SetupProfile.laptop.roles, [.intercom, .worker])
        XCTAssertEqual(SetupProfile.laptop.defaultPairingDeviceID, "laptop")
        XCTAssertFalse(SetupProfile.laptop.defaultIdentity.isEmpty)
    }

    func testRoomPiPreparesPairingWithoutLocalRoles() {
        XCTAssertEqual(SetupProfile.roomPi.roles, [])
        XCTAssertEqual(SetupProfile.roomPi.defaultPairingDeviceID, "room-pi")
    }
}
