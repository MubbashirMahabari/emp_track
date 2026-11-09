@IsTest
private class LeaveRequestControllerTest {
private static User createTestUser() {
    Profile profile = [
        SELECT Id
        FROM Profile
        WHERE Name = 'Standard User'
        LIMIT 1
    ];

    User testUser = new User(
        Alias = 'eltusr',
        Email = 'eltuser@test.com',
        EmailEncodingKey = 'UTF-8',
        LastName = 'Test User',
        LanguageLocaleKey = 'en_US',
        LocaleSidKey = 'en_US',
        ProfileId = profile.Id,
        TimeZoneSidKey = 'Asia/Kolkata',
        Username = 'eltuser' + String.valueOf(DateTime.now().getTime()) + '@test.com'
    );

    insert testUser;

    return testUser;
}

private static User createHRUser() {
    User hrUser = createTestUser();

    PermissionSet hrPermissionSet = [
        SELECT Id
        FROM PermissionSet
        WHERE Name = 'ELT_HR_Permission_Set'
        LIMIT 1
    ];

    insert new PermissionSetAssignment(
        AssigneeId = hrUser.Id,
        PermissionSetId = hrPermissionSet.Id
    );

    return hrUser;
}

private static Employee__c createEmployee(User managerUser) {
    Employee__c employee = new Employee__c(
        Employee_Name__c = 'John Smith',
        Employee_Email__c = 'john.smith@test.com',
        Employee_Code__c = 'EMP001',
        Department__c = 'Engineering',
        Job_Title__c = 'Software Engineer',
        Manager__c = managerUser.Id,
        Joining_Date__c = Date.newInstance(2026, 1, 15),
        Status__c = 'Active'
    );

    insert employee;

    return employee;
}

@IsTest
static void createLeaveRequest_createsRequest() {

    User hrUser = createHRUser();

    System.runAs(hrUser) {

        Employee__c employee =
            createEmployee(hrUser);

        Leave_Request__c request =
            new Leave_Request__c(
                Employee__c = employee.Id,
                Manager__c = hrUser.Id,
                From_Date__c = Date.newInstance(2026, 3, 1),
                To_Date__c = Date.newInstance(2026, 3, 2),
                Leave_Type__c = 'Casual Leave',
                Reason__c = 'Personal work'
            );

        Test.startTest();

        Leave_Request__c result =
            LeaveRequestController.createLeaveRequest(request);

        Test.stopTest();

        System.assertNotEquals(
            null,
            result.Id,
            'Leave request should be created.'
        );

        System.assertEquals(
            'Pending Manager Approval',
            result.Status__c,
            'New leave request should be pending manager approval.'
        );

        System.assertEquals(
            hrUser.Id,
            result.Submitted_By__c,
            'Submitted By should be the current user.'
        );
    }
}

@IsTest
static void createLeaveRequest_requiresPermission() {

    User unauthorizedUser = createTestUser();

    System.runAs(unauthorizedUser) {

        Employee__c employee =
            createEmployee(unauthorizedUser);

        Leave_Request__c request =
            new Leave_Request__c(
                Employee__c = employee.Id,
                Manager__c = unauthorizedUser.Id,
                From_Date__c = Date.newInstance(2026, 3, 1),
                To_Date__c = Date.newInstance(2026, 3, 2),
                Leave_Type__c = 'Casual Leave',
                Reason__c = 'Personal work'
            );

        Test.startTest();

        try {

            LeaveRequestController.createLeaveRequest(request);

            System.assert(
                false,
                'User without permission should not create leave requests.'
            );

        } catch (AuraHandledException e) {

            System.assertEquals(
                'You are not authorized to create leave requests.',
                e.getMessage(),
                'Unauthorized users should receive the expected error.'
            );
        }

        Test.stopTest();
    }
}

@IsTest
static void createLeaveRequest_rejectsInvalidDateRange() {

    User hrUser = createHRUser();

    System.runAs(hrUser) {

        Employee__c employee =
            createEmployee(hrUser);

        Leave_Request__c request =
            new Leave_Request__c(
                Employee__c = employee.Id,
                Manager__c = hrUser.Id,
                From_Date__c = Date.newInstance(2026, 3, 10),
                To_Date__c = Date.newInstance(2026, 3, 5),
                Leave_Type__c = 'Casual Leave',
                Reason__c = 'Personal work'
            );

        Test.startTest();

        try {

            LeaveRequestController.createLeaveRequest(request);

            System.assert(
                false,
                'Invalid date range should be rejected.'
            );

        } catch (AuraHandledException e) {

            System.assertEquals(
                'To date cannot be earlier than from date.',
                e.getMessage()
            );
        }

        Test.stopTest();
    }
}

@IsTest
static void createLeaveRequest_requiresEmployee() {

    User hrUser = createHRUser();

    System.runAs(hrUser) {

        Leave_Request__c request =
            new Leave_Request__c(
                Manager__c = hrUser.Id,
                From_Date__c = Date.newInstance(2026, 3, 1),
                To_Date__c = Date.newInstance(2026, 3, 2),
                Leave_Type__c = 'Casual Leave',
                Reason__c = 'Personal work'
            );

        Test.startTest();

        try {

            LeaveRequestController.createLeaveRequest(request);

            System.assert(
                false,
                'Employee should be required.'
            );

        } catch (AuraHandledException e) {

            System.assertEquals(
                'Employee is required.',
                e.getMessage()
            );
        }

        Test.stopTest();
    }
}

@IsTest
static void getLeaveRequests_returnsRequests() {

    User hrUser = createHRUser();

    System.runAs(hrUser) {

        Employee__c employee =
            createEmployee(hrUser);

        Leave_Request__c request =
            new Leave_Request__c(
                Employee__c = employee.Id,
                Manager__c = hrUser.Id,
                From_Date__c = Date.newInstance(2026, 3, 1),
                To_Date__c = Date.newInstance(2026, 3, 2),
                Leave_Type__c = 'Casual Leave',
                Reason__c = 'Personal work',
                Status__c = 'Pending Manager Approval'
            );

        insert request;

        // Confirm record exists
        List<Leave_Request__c> directQuery = [
            SELECT
                Id,
                Status__c,
                Employee__c,
                Manager__c
            FROM Leave_Request__c
            WHERE Id = :request.Id
        ];

        System.debug('DIRECT QUERY SIZE = ' + directQuery.size());
        System.debug('DIRECT QUERY = ' + directQuery);

        Test.startTest();

        List<Leave_Request__c> requests =
            LeaveRequestController.getLeaveRequests(null);

        Test.stopTest();

        System.debug('CONTROLLER RESULT SIZE = ' + requests.size());
        System.debug('CONTROLLER RESULT = ' + requests);

        System.assertEquals(
            1,
            requests.size(),
            'One leave request should be returned.'
        );

        System.assertEquals(
            'Casual Leave',
            requests[0].Leave_Type__c
        );

        System.assertEquals(
            'Pending Manager Approval',
            requests[0].Status__c
        );
    }
}

@IsTest
static void getLeaveRequests_filtersByStatus() {

    User hrUser = createHRUser();

    System.runAs(hrUser) {

        Employee__c employee =
            createEmployee(hrUser);

        Leave_Request__c pendingRequest =
            new Leave_Request__c(
                Employee__c = employee.Id,
                Manager__c = hrUser.Id,
                From_Date__c = Date.newInstance(2026, 3, 1),
                To_Date__c = Date.newInstance(2026, 3, 2),
                Leave_Type__c = 'Casual Leave',
                Reason__c = 'Personal work',
                Status__c = 'Pending Manager Approval'
            );

        insert pendingRequest;

        

        Test.startTest();

        List<Leave_Request__c> requests =
            LeaveRequestController.getLeaveRequests(
                'Approved'
            );

        Test.stopTest();

        System.assertEquals(
            0,
            requests.size(),
            'Approved filter should not return pending requests.'
        );
    }
}
}