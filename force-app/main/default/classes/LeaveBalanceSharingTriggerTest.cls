@IsTest
private class LeaveBalanceSharingTriggerTest {

    private static User createManager() {

        Profile profile = [
            SELECT Id
            FROM Profile
            WHERE Name = 'Standard User'
            LIMIT 1
        ];

        String uniqueValue =
            String.valueOf(DateTime.now().getTime());

        User manager = new User(
            Alias = 'lbmgr',
            Email = 'lbmanager' + uniqueValue + '@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Balance Manager',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = profile.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            Username = 'lbmanager' + uniqueValue + '@test.com'
        );

        insert manager;
        return manager;
    }

    private static Employee__c createEmployee(
        Id managerId,
        String employeeCode
    ) {
        Employee__c employee = new Employee__c(
            Employee_Name__c = 'Test Employee',
            Employee_Email__c = employeeCode + '@test.com',
            Employee_Code__c = employeeCode,
            Department__c = 'Engineering',
            Job_Title__c = 'Developer',
            Manager__c = managerId,
            Joining_Date__c = Date.newInstance(2026, 1, 15),
            Status__c = 'Active'
        );

        insert employee;
        return employee;
    }

    private static Leave_Balance__c createBalance(
        Id employeeId
    ) {
        return new Leave_Balance__c(
            Employee__c = employeeId,
            Year__c = '2026',
            Casual_Leave__c = 12,
            Sick_Leave__c = 10,
            Annual_Leave__c = 15,
            Used_Leave__c = 0
        );
    }

    @IsTest
    static void trigger_sharesBalanceWithAssignedManager() {

        User manager = createManager();

        Employee__c employee =
            createEmployee(manager.Id, 'LB001');

        Test.startTest();

        Leave_Balance__c balance = createBalance(employee.Id);
        insert balance;

        Test.stopTest();

        List<Leave_Balance__Share> shares = [
            SELECT Id, ParentId, UserOrGroupId,
                   AccessLevel, RowCause
            FROM Leave_Balance__Share
            WHERE ParentId = :balance.Id
            AND UserOrGroupId = :manager.Id
        ];

        System.assertEquals(
            1,
            shares.size(),
            'One manager share should be created.'
        );

        System.assertEquals('Read', shares[0].AccessLevel);

        System.assertEquals(
            Schema.Leave_Balance__Share.RowCause.Manager_Access__c,
            shares[0].RowCause
        );
    }

    @IsTest
    static void trigger_doesNotShareWhenEmployeeHasNoManager() {

        Employee__c employee =
            createEmployee(null, 'LB002');

        Test.startTest();

        Leave_Balance__c balance = createBalance(employee.Id);
        insert balance;

        Test.stopTest();

        List<Leave_Balance__Share> shares = [
            SELECT Id
            FROM Leave_Balance__Share
            WHERE ParentId = :balance.Id
            AND RowCause =
                :Schema.Leave_Balance__Share.RowCause.Manager_Access__c
        ];

        System.assertEquals(
            0,
            shares.size(),
            'No manager share should be created without an assigned manager.'
        );
    }

    @IsTest
    static void trigger_handlesMultipleBalances() {

        User manager = createManager();

        Employee__c employee1 =
            createEmployee(manager.Id, 'LB003');

        Employee__c employee2 =
            createEmployee(manager.Id, 'LB004');

        List<Leave_Balance__c> balances =
            new List<Leave_Balance__c>{
                createBalance(employee1.Id),
                createBalance(employee2.Id)
            };

        Test.startTest();

        insert balances;

        Test.stopTest();

        Set<Id> balanceIds = new Map<Id, Leave_Balance__c>(
            balances
        ).keySet();

        List<Leave_Balance__Share> shares = [
            SELECT Id, ParentId, UserOrGroupId, AccessLevel
            FROM Leave_Balance__Share
            WHERE ParentId IN :balanceIds
            AND UserOrGroupId = :manager.Id
            AND RowCause =
                :Schema.Leave_Balance__Share.RowCause.Manager_Access__c
        ];

        System.assertEquals(
            2,
            shares.size(),
            'Both balance records should be shared with the manager.'
        );

        for (Leave_Balance__Share shareRecord : shares) {
            System.assertEquals('Read', shareRecord.AccessLevel);
        }
    }
}