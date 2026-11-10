@IsTest
private class LeaveApprovalServiceTest {

    private static User createTestUser() {

        Profile profile = [
            SELECT Id
            FROM Profile
            WHERE Name = 'Standard User'
            LIMIT 1
        ];

        User testUser = new User(
            Alias = 'apprusr',
            Email = 'approval@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Approval User',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = profile.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            Username =
                'approval' +
                String.valueOf(DateTime.now().getTime()) +
                '@test.com'
        );

        insert testUser;

        return testUser;
    }


    private static User createManagerUser() {

        User managerUser = createTestUser();

        PermissionSet managerPermissionSet = [
            SELECT Id
            FROM PermissionSet
            WHERE Name = 'ELT_Manager_Permission_Set'
            LIMIT 1
        ];

        insert new PermissionSetAssignment(
            AssigneeId = managerUser.Id,
            PermissionSetId = managerPermissionSet.Id
        );

        return managerUser;
    }


    private static Employee__c createEmployee(User managerUser) {

        Employee__c employee = new Employee__c(
            Employee_Name__c = 'John Smith',
            Employee_Email__c = 'john.approval@test.com',
            Employee_Code__c = 'APP001',
            Department__c = 'Engineering',
            Job_Title__c = 'Software Engineer',
            Manager__c = managerUser.Id,
            Joining_Date__c = Date.newInstance(2026, 1, 15),
            Status__c = 'Active'
        );

        insert employee;

        return employee;
    }


    private static Leave_Request__c createPendingRequest(
        Employee__c employee,
        User managerUser
    ) {

        Leave_Request__c request = new Leave_Request__c(
            Employee__c = employee.Id,
            Manager__c = managerUser.Id,
            From_Date__c = Date.newInstance(2026, 10, 1),
            To_Date__c = Date.newInstance(2026, 10, 2),
            Leave_Type__c = 'Casual Leave',
            Reason__c = 'Personal work',
            Status__c = 'Pending Manager Approval'
        );

        insert request;

        return request;
    }

private static Leave_Balance__c createLeaveBalance(
    Employee__c employee,
    Integer yearValue
) {
    Leave_Balance__c balance = new Leave_Balance__c(
        Employee__c = employee.Id,
        Year__c = String.valueOf(yearValue),
        Casual_Leave__c = 12,
        Sick_Leave__c = 10,
        Annual_Leave__c = 15,
        Used_Leave__c = 0
    );

    insert balance;

    return balance;
}

    @IsTest
    static void approveLeaveRequest_approvesPendingRequest() {

        User managerUser = createManagerUser();

        System.runAs(managerUser) {

            Employee__c employee =
                createEmployee(managerUser);

            Leave_Request__c request =
                createPendingRequest(
                    employee,
                    managerUser
                );

            Leave_Balance__c balance = createLeaveBalance(
                                                   employee,
                                                request.From_Date__c.year()
                                        );  

            Test.startTest();

            Leave_Request__c result =
                LeaveApprovalService.approveLeaveRequest(
                    request.Id
                );

            Test.stopTest();

            System.assertEquals(
                'Approved',
                result.Status__c,
                'Pending request should become approved.'
            );

            System.assertEquals(
                Date.today(),
                result.Decision_Date__c,
                'Decision date should be set when approved.'
            );
        }
    }


@IsTest
static void approveLeaveRequest_requiresPermission() {

    User unauthorizedUser = createTestUser();

    System.runAs(unauthorizedUser) {

        Employee__c employee =
            createEmployee(unauthorizedUser);

        Leave_Request__c request =
            createPendingRequest(
                employee,
                unauthorizedUser
            );

        Test.startTest();

        try {

            LeaveApprovalService.approveLeaveRequest(
                request.Id
            );

            System.assert(
                false,
                'User without approval permission should not approve leave.'
            );

        } catch (AuraHandledException e) {

            System.assertEquals(
                'You are not authorized to approve leave requests.',
                e.getMessage()
            );
        }

        Test.stopTest();
    }
}


@IsTest
static void rejectLeaveRequest_rejectsWrongManager() {

    User assignedManager =
        createManagerUser();

    User otherManager =
        createManagerUser();

    System.runAs(assignedManager) {

        Employee__c employee =
            createEmployee(assignedManager);

        Leave_Request__c request =
            createPendingRequest(
                employee,
                assignedManager
            );

        insert new Employee__Share(
            ParentId = employee.Id,
            UserOrGroupId = otherManager.Id,
            AccessLevel = 'Read',
            RowCause = Schema.Employee__Share.RowCause.Manual
        );

        insert new Leave_Request__Share(
            ParentId = request.Id,
            UserOrGroupId = otherManager.Id,
            AccessLevel = 'Edit',
            RowCause = Schema.Leave_Request__Share.RowCause.Manual
        );

        System.runAs(otherManager) {

            Test.startTest();

            try {

                LeaveApprovalService.rejectLeaveRequest(
                    request.Id,
                    'Not my employee.'
                );

                System.assert(
                    false,
                    'Only the assigned manager should reject the request.'
                );

            } catch (AuraHandledException e) {

                System.assertEquals(
                    'You are not the assigned manager for this leave request.',
                    e.getMessage()
                );
            }

            Test.stopTest();
        }
    }
}

@IsTest
static void approveLeaveRequest_rejectsNonPendingRequest() {

    User managerUser =
        createManagerUser();

        System.runAs(managerUser) {

            Employee__c employee =
                createEmployee(managerUser);

            Leave_Request__c request =
                new Leave_Request__c(
                    Employee__c = employee.Id,
                    Manager__c = managerUser.Id,
                    From_Date__c = Date.newInstance(2026, 10, 1),
                    To_Date__c = Date.newInstance(2026, 10, 2),
                    Leave_Type__c = 'Casual Leave',
                    Reason__c = 'Personal work',
                    Status__c = 'Approved',
                    Decision_Date__c = Date.today()
                );

            insert request;

            Test.startTest();

            try {

                LeaveApprovalService.approveLeaveRequest(
                    request.Id
                );

                System.assert(
                    false,
                    'An already approved request should not be approved again.'
                );

            } catch (AuraHandledException e) {

                System.assertEquals(
                    'Only pending leave requests can be approved.',
                    e.getMessage()
                );
            }

            Test.stopTest();
        }
    }


@IsTest
static void rejectLeaveRequest_rejectsPendingRequest() {

    User managerUser = createManagerUser();

    System.runAs(managerUser) {

        Employee__c employee =
            createEmployee(managerUser);

        Leave_Request__c request =
            createPendingRequest(
                employee,
                managerUser
            );

        Test.startTest();

        Leave_Request__c result =
            LeaveApprovalService.rejectLeaveRequest(
                request.Id,
                'Leave dates conflict with project delivery.'
            );

        Test.stopTest();

        System.assertEquals(
            'Rejected',
            result.Status__c,
            'Pending request should become rejected.'
        );

        System.assertEquals(
            'Leave dates conflict with project delivery.',
            result.Manager_Comment__c,
            'Manager comment should be stored.'
        );

        System.assertEquals(
            Date.today(),
            result.Decision_Date__c,
            'Decision date should be set.'
        );
    }
}

@IsTest
static void rejectLeaveRequest_requiresComment() {

    User managerUser = createManagerUser();

    System.runAs(managerUser) {

        Employee__c employee =
            createEmployee(managerUser);

        Leave_Request__c request =
            createPendingRequest(
                employee,
                managerUser
            );

        Test.startTest();

        try {

            LeaveApprovalService.rejectLeaveRequest(
                request.Id,
                null
            );

            System.assert(
                false,
                'Rejection without a manager comment should fail.'
            );

        } catch (AuraHandledException e) {

            System.assertEquals(
                'Manager comment is required when rejecting a leave request.',
                e.getMessage()
            );
        }

        Test.stopTest();
    }
}

@IsTest
static void rejectLeaveRequest_requiresPermission() {

    User unauthorizedUser = createTestUser();

    System.runAs(unauthorizedUser) {

        Employee__c employee =
            createEmployee(unauthorizedUser);

        Leave_Request__c request =
            createPendingRequest(
                employee,
                unauthorizedUser
            );

        Test.startTest();

        try {

            LeaveApprovalService.rejectLeaveRequest(
                request.Id,
                'Not approved.'
            );

            System.assert(
                false,
                'User without rejection permission should not reject leave.'
            );

        } catch (AuraHandledException e) {

            System.assertEquals(
                'You are not authorized to reject leave requests.',
                e.getMessage()
            );
        }

        Test.stopTest();
    }
}

@IsTest
static void approveLeaveRequest_rejectsMissingBalance() {

    User managerUser = createManagerUser();

    System.runAs(managerUser) {

        Employee__c employee =
            createEmployee(managerUser);

        Leave_Request__c request =
            createPendingRequest(employee, managerUser);

        // Intentionally do not create a Leave_Balance__c record.

        Test.startTest();

        try {
            LeaveApprovalService.approveLeaveRequest(request.Id);

            System.assert(
                false,
                'Approval should fail when leave balance is missing.'
            );

        } catch (AuraHandledException e) {

            System.assert(
                e.getMessage().contains('Leave balance not found'),
                'Expected missing leave balance error.'
            );
        }

        Test.stopTest();
    }
}

@IsTest
static void approveLeaveRequest_validatesCategorySpecificBalance() {

    User managerUser = createManagerUser();

    System.runAs(managerUser) {

        Employee__c employee =
            createEmployee(managerUser);

        Leave_Request__c request =
            createPendingRequest(employee, managerUser);

        // Create the employee's 2026 leave balance.
        Leave_Balance__c balance = createLeaveBalance(
            employee,
            request.From_Date__c.year()
        );

        // Casual Leave entitlement is only 1 day.
        // Sick Leave and Annual Leave remain 10 and 15 days.
        balance.Casual_Leave__c = 1;
        update balance;

        Test.startTest();

        try {

            // The request is for 2 days of Casual Leave.
            LeaveApprovalService.approveLeaveRequest(request.Id);

            System.assert(
                false,
                'Approval should fail because Casual Leave balance is insufficient.'
            );

        } catch (AuraHandledException e) {

            System.assert(
                e.getMessage().contains('Insufficient Casual Leave'),
                'Expected Casual Leave balance validation error.'
            );
        }

        Test.stopTest();
    }
}

@IsTest
static void approveLeaveRequest_deductsPreviouslyApprovedLeave() {

    User managerUser = createManagerUser();

    System.runAs(managerUser) {

        Employee__c employee =
            createEmployee(managerUser);

        // Total Casual Leave entitlement = 12 days.
        createLeaveBalance(
            employee,
            2026
        );

        // Previously approved Casual Leave = 4 days.
        Leave_Request__c previousRequest = new Leave_Request__c(
            Employee__c = employee.Id,
            Manager__c = managerUser.Id,
            From_Date__c = Date.newInstance(2026, 9, 1),
            To_Date__c = Date.newInstance(2026, 9, 4),
            Leave_Type__c = 'Casual Leave',
            Reason__c = 'Previously approved leave',
            Status__c = 'Approved',
            Decision_Date__c = Date.newInstance(2026, 8, 25)
        );

        insert previousRequest;

        // New request = 9 days.
        Leave_Request__c request =
            createPendingRequest(employee, managerUser);

        request.From_Date__c = Date.newInstance(2026, 10, 1);
        request.To_Date__c = Date.newInstance(2026, 10, 9);
        update request;

        // Available = 12 - 4 = 8 days.
        // Requested = 9 days. Approval must fail.

        Test.startTest();

        try {

            LeaveApprovalService.approveLeaveRequest(request.Id);

            System.assert(
                false,
                'Approval should fail when previously approved leave reduces the available balance.'
            );

        } catch (AuraHandledException e) {

            System.assert(
                e.getMessage().contains('Insufficient Casual Leave'),
                'Expected insufficient Casual Leave error.'
            );
        }

        Test.stopTest();
    }
}

@IsTest
static void approveLeaveRequest_afterManagerReassignment() {

    User managerA = createManagerUser();
    User managerB = createManagerUser();

    Employee__c employee;
    Leave_Request__c request;

    System.runAs(managerA) {

        // Create employee assigned to Manager A.
        employee = createEmployee(managerA);

        // Create pending leave request assigned to Manager A.
        request = createPendingRequest(
            employee,
            managerA
        );

        // Create sufficient leave balance.
        createLeaveBalance(
            employee,
            request.From_Date__c.year()
        );

        // Create initial sharing for Manager A.
        LeaveTrackerSharingService.shareEmployeeWithManager(
            employee.Id,
            managerA.Id
        );

        LeaveTrackerSharingService.shareLeaveRequestWithManager(
            request.Id,
            managerA.Id
        );

        // Update employee's assigned manager.
        employee.Manager__c = managerB.Id;
        update employee;

        // Synchronize access and reassign pending request.
LeaveTrackerSharingService.syncEmployeeManagerAccess(
    employee.Id,
    managerA.Id,
    managerB.Id
);
    }

    // Manager B should now be able to approve the request.
    System.runAs(managerB) {

        Test.startTest();

        Leave_Request__c result =
            LeaveApprovalService.approveLeaveRequest(
                request.Id
            );

        Test.stopTest();

        System.assertEquals(
            managerB.Id,
            result.Manager__c,
            'Pending request should be assigned to Manager B.'
        );

        System.assertEquals(
            'Approved',
            result.Status__c,
            'Newly assigned manager should be able to approve the request.'
        );
    }
}

}