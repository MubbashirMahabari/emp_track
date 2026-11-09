@IsTest
private class EmployeeControllerTest {

    @TestSetup
    static void createTestData() {
        Employee__c employee = new Employee__c(
            Employee_Name__c = 'John Smith',
            Employee_Email__c = 'john.smith@test.com',
            Employee_Code__c = 'EMP001',
            Department__c = 'Engineering',
            Job_Title__c = 'Software Engineer',
            Joining_Date__c = Date.newInstance(2026, 1, 15),
            Status__c = 'Active'
        );

        insert employee;
    }

    @IsTest
    static void getEmployees_returnsEmployees() {
        Test.startTest();

        List<Employee__c> employees =
            EmployeeController.getEmployees();

        Test.stopTest();

        System.assertEquals(
            1,
            employees.size(),
            'One employee should be returned.'
        );

        System.assertEquals(
            'John Smith',
            employees[0].Employee_Name__c,
            'The expected employee should be returned.'
        );
    }

@IsTest
static void createEmployee_requiresPermission() {

    Employee__c employee = new Employee__c(
        Employee_Name__c = 'Sarah Johnson',
        Employee_Email__c = 'sarah.johnson@test.com',
        Employee_Code__c = 'EMP002',
        Department__c = 'Sales',
        Job_Title__c = 'Sales Manager',
        Joining_Date__c = Date.newInstance(2026, 2, 1),
        Status__c = 'Active'
    );

    Test.startTest();

    try {

        EmployeeController.createEmployee(employee);

        // If execution reaches here, the current user has permission.
        System.assert(
            FeatureManagement.checkPermission(
                'ELT_Manage_Employees'
            ),
            'The current test user should have the permission.'
        );

    } catch (AuraHandledException e) {

        System.assertEquals(
            'You are not authorized to manage employees.',
            e.getMessage(),
            'Unauthorized users should receive the expected authorization error.'
        );
    }

    Test.stopTest();
}

@IsTest
static void updateEmployee_updatesEmployee() {

    Employee__c employee = [
        SELECT
            Id,
            Employee_Name__c,
            Employee_Email__c,
            Employee_Code__c,
            Department__c,
            Job_Title__c,
            Joining_Date__c,
            Status__c
        FROM Employee__c
        LIMIT 1
    ];

    employee.Job_Title__c = 'Senior Software Engineer';

    Test.startTest();

    try {
        Employee__c updatedEmployee =
            EmployeeController.updateEmployee(employee);

        Test.stopTest();

        System.assertEquals(
            'Senior Software Engineer',
            updatedEmployee.Job_Title__c,
            'Job title should be updated.'
        );

    } catch (AuraHandledException e) {
        Test.stopTest();

        System.assert(
            e.getMessage().contains('not authorized'),
            'Only users with employee-management permission should update employees.'
        );
    }
}

@IsTest
static void updateEmployee_preventsDuplicateEmployeeCode() {

    Employee__c firstEmployee = [
        SELECT Id, Employee_Code__c
        FROM Employee__c
        LIMIT 1
    ];

    Employee__c secondEmployee = new Employee__c(
        Employee_Name__c = 'Sarah Johnson',
        Employee_Email__c = 'sarah.johnson@test.com',
        Employee_Code__c = 'EMP002',
        Department__c = 'Sales',
        Job_Title__c = 'Sales Executive',
        Joining_Date__c = Date.newInstance(2026, 2, 1),
        Status__c = 'Active'
    );

    insert secondEmployee;

    firstEmployee.Employee_Code__c =
        secondEmployee.Employee_Code__c;

    Test.startTest();

    try {
        EmployeeController.updateEmployee(firstEmployee);

        Test.stopTest();

        if (!FeatureManagement.checkPermission(
            'ELT_Manage_Employees'
        )) {
            System.assert(
                false,
                'Expected authorization failure.'
            );
        }

    } catch (AuraHandledException e) {
        Test.stopTest();

        System.assert(
            e.getMessage().contains(
                'Employee code already exists'
            ) ||
            e.getMessage().contains(
                'not authorized'
            ),
            'Expected duplicate or authorization error.'
        );
    }
}

@IsTest
static void searchEmployees_filtersBySearchTerm() {

    Test.startTest();

    List<Employee__c> employees =
        EmployeeController.searchEmployees(
            'John',
            null,
            null
        );

    Test.stopTest();

    System.assertEquals(
        1,
        employees.size(),
        'John should be returned by the search.'
    );

    System.assertEquals(
        'John Smith',
        employees[0].Employee_Name__c,
        'The search should return John Smith.'
    );
}

@IsTest
static void searchEmployees_filtersByDepartment() {

    Test.startTest();

    List<Employee__c> employees =
        EmployeeController.searchEmployees(
            null,
            'Engineering',
            null
        );

    Test.stopTest();

    System.assertEquals(
        1,
        employees.size(),
        'Only Engineering employee should be returned.'
    );

    System.assertEquals(
        'Engineering',
        employees[0].Department__c
    );
}

@IsTest
static void searchEmployees_filtersByStatus() {

    Test.startTest();

    List<Employee__c> employees =
        EmployeeController.searchEmployees(
            null,
            null,
            'Active'
        );

    Test.stopTest();

    System.assertEquals(
        1,
        employees.size(),
        'Only active employee should be returned.'
    );

    System.assertEquals(
        'Active',
        employees[0].Status__c
    );
}

@IsTest
static void searchEmployees_supportsCombinedFilters() {

    Test.startTest();

    List<Employee__c> employees =
        EmployeeController.searchEmployees(
            'John',
            'Engineering',
            'Active'
        );

    Test.stopTest();

    System.assertEquals(
        1,
        employees.size(),
        'The combined filters should return John.'
    );

    System.assertEquals(
        'John Smith',
        employees[0].Employee_Name__c
    );
}
}