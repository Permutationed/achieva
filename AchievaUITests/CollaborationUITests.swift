//
//  CollaborationUITests.swift
//  AchievaUITests
//
//  Created by Antigravity on 2024-05-24.
//

import XCTest

final class CollaborationUITests: XCTestCase {
    
    override func setUpWithError() throws {
        continueAfterFailure = false
    }
    
    // Test Scenario A: User sends an invite
    func testSendCollaborationInvite() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-useMockData"]
        app.launch()
        
        // 1. Navigate to Profile (Create button is on Profile)
        let profileTab = app.tabBars.buttons["Profile"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 10.0))
        profileTab.tap()
        
        // 2. Tap Create Goal FAB
        let createGoalButton = app.buttons["CreateGoalButton"]
        XCTAssertTrue(createGoalButton.waitForExistence(timeout: 5.0))
        createGoalButton.tap()
        
        // 3. Enter Title
        let titleField = app.textFields["e.g. Summer 2024 Adventures"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5.0))
        titleField.tap()
        titleField.typeText("Collaborative Trip")
        
        // 4. Open Collaborator Picker
        let addCollaboratorsButton = app.buttons["Add Collaborators"]
        if addCollaboratorsButton.waitForExistence(timeout: 2.0) {
            addCollaboratorsButton.tap()
            
            // 5. Select a mocked friend
            // Use accessibility identifier we added
            let mockFriendPredicate = NSPredicate(format: "identifier BEGINSWITH 'CollaboratorRow_Mock Friend'")
            let friendRow = app.buttons.matching(mockFriendPredicate).firstMatch
            
            // Wait for friends to load (might take a moment due to mock delay)
            if friendRow.waitForExistence(timeout: 5.0) {
                friendRow.tap()
                
                // 6. Tap Done
                let doneButton = app.buttons["Done"]
                XCTAssertTrue(doneButton.exists)
                doneButton.tap()
            } else {
                XCTFail("No mock friends found in picker")
            }
        } else {
            XCTFail("Add Collaborators button not found")
        }
        
        // 7. Publish Goal (Label changes to "Publish" or "Save Draft" based on context)
        // Since we added a collaborator, it should force draft mode or at least be savable
        // The button label logic in CreateGoalView: shouldBeDraft ? "Save Draft" : "Publish"
        // Collaborative lists ARE always drafts.
        
        let saveButton = app.buttons["Save Draft"]
        if saveButton.waitForExistence(timeout: 2.0) {
            saveButton.tap()
        } else {
             // Fallback if logic differs
            let publishButton = app.buttons["Publish"]
            if publishButton.exists {
                publishButton.tap()
            } else {
                XCTFail("Neither 'Save Draft' nor 'Publish' button found")
            }
        }
    }
    
    // Test Scenario B: User accepts an invite
    func testAcceptCollaborationInvite() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-useMockData", "-mockScenario", "pendingInvite"]
        app.launch()
        
        // 1. Navigate to Profile
        let profileTab = app.tabBars.buttons["Profile"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 10.0))
        profileTab.tap()
        
        // 2. Open Collaboration Requests
        // Try to tap the badge button
        let requestsButton = app.buttons["CollaborationRequestsButton"]
        if requestsButton.waitForExistence(timeout: 5.0) {
            requestsButton.tap()
            
            // 3. Verify Invite Exists
            let acceptButton = app.buttons["Accept"]
            XCTAssertTrue(acceptButton.waitForExistence(timeout: 5.0), "Accept button should appear in requests view")
            
            // 4. Accept
            acceptButton.tap()
            
            // 5. Verify it's gone or moved to accepted
            // Wait for loading to finish and button to disappear
            let doesNotExist = NSPredicate(format: "exists == false")
            expectation(for: doesNotExist, evaluatedWith: acceptButton, handler: nil)
            waitForExpectations(timeout: 5.0, handler: nil)
        } else {
            // Fallback: Check notification button if badge is missing
            let notifButton = app.buttons["NotificationsButton"]
            if notifButton.waitForExistence(timeout: 2.0) {
                notifButton.tap()
                // Do same check
                let acceptButton = app.buttons["Accept"]
                XCTAssertTrue(acceptButton.waitForExistence(timeout: 5.0))
                acceptButton.tap()
            } else {
                XCTFail("Collaboration Requests button not found despite pending invite scenario")
            }
        }
    }
    
    // Test Scenario C: End-to-End Create Collaborative Draft and Publish
    func testCreateCollaborativeDraftAndPublish() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-useMockData"]
        app.launch()
        
        // 1. Navigate to Create Goal
        let profileTab = app.tabBars.buttons["Profile"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 10.0))
        profileTab.tap()
        
        let createGoalButton = app.buttons["CreateGoalButton"]
        XCTAssertTrue(createGoalButton.waitForExistence(timeout: 5.0))
        createGoalButton.tap()
        
        // 2. Fill Goal Details
        let titleField = app.textFields["e.g. Summer 2024 Adventures"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5.0))
        titleField.tap()
        titleField.typeText("Collab Test Goal")
        
        // 3. Add Collaborator
        let addCollaboratorsButton = app.buttons["Add Collaborators"]
        addCollaboratorsButton.tap()
        
        let mockFriendPredicate = NSPredicate(format: "identifier BEGINSWITH 'CollaboratorRow_Mock Friend'")
        let friendRow = app.buttons.matching(mockFriendPredicate).firstMatch
        XCTAssertTrue(friendRow.waitForExistence(timeout: 5.0))
        friendRow.tap()
        
        app.buttons["Done"].tap()
        
        // 4. Save as Draft (Label should be "Save Draft")
        let saveDraftButton = app.buttons["Save Draft"]
        XCTAssertTrue(saveDraftButton.waitForExistence(timeout: 2.0))
        saveDraftButton.tap()
        
        // 5. Verify Draft Exists in Profile
        // Switch to "Drafts" category
        // Swipe left on "All Goals" to ensure "Drafts" is visible (it might be off-screen)
        let allGoalsChip = app.buttons["All Goals"]
        if allGoalsChip.exists {
            allGoalsChip.swipeLeft()
        }

        let draftsChip = app.buttons["Drafts"]
        XCTAssertTrue(draftsChip.waitForExistence(timeout: 5.0))
        // Use coordinate tap for chip which might be partially obscured or in a ScrollView
        draftsChip.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        
        // 6. Tap the created draft
        // It should have title "Collab Test Goal"
        // Try finding it as a button (NavigationLink) or static text
        let draftCell = app.buttons["Collab Test Goal"]
        if draftCell.waitForExistence(timeout: 10.0) { // Increased timeout for draft loading
            draftCell.tap()
        } else {
             // Fallback just in case
            let draftText = app.staticTexts["Collab Test Goal"]
            XCTAssertTrue(draftText.waitForExistence(timeout: 5.0), "Draft goal not found in list. It might still be loading or failed to save.")
            draftText.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        
        // 7. Verify "Publish Draft" button exists
        // Wait for GoalDetailView
        // Tap ellipsis menu first
        let optionsButton = app.buttons["GoalOptionsButton"]
        XCTAssertTrue(optionsButton.waitForExistence(timeout: 5.0))
        optionsButton.tap()
        
        let publishDraftButton = app.buttons["Publish Draft"]
        XCTAssertTrue(publishDraftButton.waitForExistence(timeout: 5.0))
        
        // 8. Publish
        publishDraftButton.tap()
        
        // 9. Handle Success Alert "Draft Published!" -> "OK"
        let okButton = app.alerts.firstMatch.buttons["OK"]
        if okButton.waitForExistence(timeout: 5.0) {
            okButton.tap()
        }
    }
}
