@IsTest
private class LeaveTrackerSharingServiceTest {

    private static User createManager(String suffix) {

        Profile profile = [
            SELECT Id
            FROM Profile
            WHERE Name = 'Standard User'
            LIMIT 1
        ];

        User manager = new User(
            Alias = 'mgr' + suffix,
            Email = 'manager' + suffix + '@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Manager ' + suffix,
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = profile.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            Username = 'manager' + suffix + '@test.com'
        );

        insert manager;
        return manager;
    }

    @IsTest
    static void syncEmployeeManagerAccess_reassignsAllRecords() {

        User managerA = createManager('A');
        User managerB = createManager('B');

        System.runAs(managerA) {

            Employee__c employee = new Employee__c(
                Employee_Name__c = 'Test Employee',
                Employee_Email__c = 'sharing.employee@test.com',
                Employee_Code__c = 'SHARE001',
                Department__c = 'Engineering',
                Job_Title__c = 'Developer',
                Manager__c = managerA.Id,
                Joining_Date__c = Date.newInstance(2026, 1, 15),
                Status__c = 'Active'
            );

            insert employee;

            Leave_Request__c request = new Leave_Request__c(
                Employee__c = employee.Id,
                Manager__c = managerA.Id,
                From_Date__c = Date.newInstance(2026, 10, 1),
                To_Date__c = Date.newInstance(2026, 10, 2),
                Leave_Type__c = 'Casual Leave',
                Reason__c = 'Personal work',
                Status__c = 'Pending Manager Approval'
            );

            insert request;

            Leave_Balance__c balance = new Leave_Balance__c(
                Employee__c = employee.Id,
                Year__c = '2026',
                Casual_Leave__c = 12,
                Sick_Leave__c = 10,
                Annual_Leave__c = 15,
                Used_Leave__c = 0
            );

            insert balance;

            // Initially share all records with Manager A.
            LeaveTrackerSharingService.shareEmployeeWithManager(
                employee.Id,
                managerA.Id
            );

            LeaveTrackerSharingService.shareLeaveRequestWithManager(
                request.Id,
                managerA.Id
            );

            LeaveTrackerSharingService.shareLeaveBalanceWithManager(
                balance.Id,
                managerA.Id
            );

            Test.startTest();

            // Reassign employee from Manager A to Manager B.
            LeaveTrackerSharingService.syncEmployeeManagerAccess(
                employee.Id,
                managerA.Id,
                managerB.Id
            );

            Test.stopTest();

            // Verify Manager A has no custom shares.
            Integer oldEmployeeShares = [
                SELECT COUNT()
                FROM Employee__Share
                WHERE ParentId = :employee.Id
                AND UserOrGroupId = :managerA.Id
                AND RowCause =
                    :Schema.Employee__Share.RowCause.Manager_Access__c
            ];

            Integer oldRequestShares = [
                SELECT COUNT()
                FROM Leave_Request__Share
                WHERE ParentId = :request.Id
                AND UserOrGroupId = :managerA.Id
                AND RowCause =
                    :Schema.Leave_Request__Share.RowCause.Manager_Access__c
            ];

            Integer oldBalanceShares = [
                SELECT COUNT()
                FROM Leave_Balance__Share
                WHERE ParentId = :balance.Id
                AND UserOrGroupId = :managerA.Id
                AND RowCause =
                    :Schema.Leave_Balance__Share.RowCause.Manager_Access__c
            ];

            System.assertEquals(0, oldEmployeeShares);
            System.assertEquals(0, oldRequestShares);
            System.assertEquals(0, oldBalanceShares);

            // Verify Manager B has the correct access.
            List<Employee__Share> newEmployeeShares = [
                SELECT AccessLevel
                FROM Employee__Share
                WHERE ParentId = :employee.Id
                AND UserOrGroupId = :managerB.Id
                AND RowCause =
                    :Schema.Employee__Share.RowCause.Manager_Access__c
            ];

            List<Leave_Request__Share> newRequestShares = [
                SELECT AccessLevel
                FROM Leave_Request__Share
                WHERE ParentId = :request.Id
                AND UserOrGroupId = :managerB.Id
                AND RowCause =
                    :Schema.Leave_Request__Share.RowCause.Manager_Access__c
            ];

            List<Leave_Balance__Share> newBalanceShares = [
                SELECT AccessLevel
                FROM Leave_Balance__Share
                WHERE ParentId = :balance.Id
                AND UserOrGroupId = :managerB.Id
                AND RowCause =
                    :Schema.Leave_Balance__Share.RowCause.Manager_Access__c
            ];

            System.assertEquals(1, newEmployeeShares.size());
            System.assertEquals('Read', newEmployeeShares[0].AccessLevel);

            System.assertEquals(1, newRequestShares.size());
            System.assertEquals('Edit', newRequestShares[0].AccessLevel);

            System.assertEquals(1, newBalanceShares.size());
            System.assertEquals('Read', newBalanceShares[0].AccessLevel);
        }
    }
}