public with sharing class EmployeeController {

    @AuraEnabled(cacheable=true)
    public static List<Employee__c> getEmployees() {
        try {
            return [
                SELECT
                    Id,
                    Name,
                    Employee_Name__c,
                    Employee_Email__c,
                    Employee_Code__c,
                    Department__c,
                    Job_Title__c,
                    Manager__c,
                    Manager__r.Name,
                    User__c,
                    Joining_Date__c,
                    Status__c
                FROM Employee__c
                WITH USER_MODE
                ORDER BY Employee_Name__c
            ];
        } catch (Exception e) {
            throw new AuraHandledException(
                'Unable to load employees.'
            );
        }
    }


    @AuraEnabled(cacheable=true)
    public static List<Employee__c> searchEmployees(
        String searchTerm,
        String department,
        String status
    ) {
    try {
        String query =
            'SELECT ' +
            'Id, ' +
            'Name, ' +
            'Employee_Name__c, ' +
            'Employee_Email__c, ' +
            'Employee_Code__c, ' +
            'Department__c, ' +
            'Job_Title__c, ' +
            'Manager__c, ' +
            'Manager__r.Name, ' +
            'User__c, ' +
            'Joining_Date__c, ' +
            'Status__c ' +
            'FROM Employee__c';

        List<String> conditions = new List<String>();
        Map<String, Object> bindVariables = new Map<String, Object>();

        // Search by employee name, code, or email
        if (!String.isBlank(searchTerm)) {
            String searchValue = '%' + searchTerm.trim() + '%';

            conditions.add(
                '(Employee_Name__c LIKE :searchValue ' +
                'OR Employee_Code__c LIKE :searchValue ' +
                'OR Employee_Email__c LIKE :searchValue)'
            );

            bindVariables.put('searchValue', searchValue);
        }

        // Filter by department
        if (!String.isBlank(department)) {
            conditions.add('Department__c = :departmentValue');
            bindVariables.put('departmentValue', department);
        }

        // Filter by status
        if (!String.isBlank(status)) {
            conditions.add('Status__c = :statusValue');
            bindVariables.put('statusValue', status);
        }

        // Add WHERE clause only when filters are provided
        if (!conditions.isEmpty()) {
            query += ' WHERE ' + String.join(conditions, ' AND ');
        }

        query += ' ORDER BY Employee_Name__c';

        return Database.queryWithBinds(
            query,
            bindVariables,
            AccessLevel.USER_MODE
        );

    } catch (Exception e) {
        throw new AuraHandledException(
            'Unable to search employees.'
        );
    }
}


    @AuraEnabled
    public static Employee__c createEmployee(Employee__c employee) {
        try {
            validateEmployeeManagementPermission();

            validateEmployee(employee);

            insert as user employee;
            LeaveTrackerSharingService.syncEmployeeManagerAccess(
                employee.Id,
                null,
                employee.Manager__c
            );
            return employee;

} catch (LeaveTrackerException e) {
    AuraHandledException ex =
        new AuraHandledException(e.getMessage());

    ex.setMessage(e.getMessage());

    throw ex;

} catch (Exception e) {
    AuraHandledException ex =
        new AuraHandledException(
            'Unable to create employee.'
        );

    ex.setMessage('Unable to create employee.');

    throw ex;
}
    }

    @AuraEnabled
    public static Employee__c updateEmployee(Employee__c employee) {
    try {
        validateEmployeeManagementPermission();

        if (employee == null || employee.Id == null) {
            throw new LeaveTrackerException(
                'Employee information is required.'
            );
        }

        validateEmployee(employee);
        validateDuplicateEmployeeCode(employee);
        Employee__c existingEmployee = [
            SELECT Id, Manager__c
            FROM Employee__c
            WHERE Id = :employee.Id
            LIMIT 1
        ];
        update as user employee;
        LeaveTrackerSharingService.syncEmployeeManagerAccess(
            employee.Id,
            existingEmployee.Manager__c,
            employee.Manager__c
        );
        return employee;

} catch (LeaveTrackerException e) {
    AuraHandledException ex =
        new AuraHandledException(e.getMessage());

    ex.setMessage(e.getMessage());

    throw ex;

} catch (Exception e) {
    AuraHandledException ex =
        new AuraHandledException(
            'Unable to update employee.'
        );

    ex.setMessage('Unable to update employee.');

    throw ex;
}
    }

    private static void validateEmployeeManagementPermission() {
        if (!FeatureManagement.checkPermission(
            'ELT_Manage_Employees'
        )) {
            throw new LeaveTrackerException(
                'You are not authorized to manage employees.'
            );
        }
    }

    private static void validateEmployee(Employee__c employee) {
        if (employee == null) {
            throw new LeaveTrackerException(
                'Employee information is required.'
            );
        }

        if (String.isBlank(employee.Employee_Name__c)) {
            throw new LeaveTrackerException(
                'Employee name is required.'
            );
        }

        if (String.isBlank(employee.Employee_Email__c)) {
            throw new LeaveTrackerException(
                'Employee email is required.'
            );
        }

        if (String.isBlank(employee.Employee_Code__c)) {
            throw new LeaveTrackerException(
                'Employee code is required.'
            );
        }

        if (String.isBlank(employee.Department__c)) {
            throw new LeaveTrackerException(
                'Department is required.'
            );
        }

        if (String.isBlank(employee.Job_Title__c)) {
            throw new LeaveTrackerException(
                'Job title is required.'
            );
        }

        if (employee.Joining_Date__c == null) {
            throw new LeaveTrackerException(
                'Joining date is required.'
            );
        }

        if (String.isBlank(employee.Status__c)) {
            throw new LeaveTrackerException(
                'Employee status is required.'
            );
        }
    }

    private static void validateDuplicateEmployeeCode(Employee__c employee) {
    List<Employee__c> existingEmployees = [
        SELECT Id
        FROM Employee__c
        WHERE Employee_Code__c = :employee.Employee_Code__c
        AND Id != :employee.Id
        WITH USER_MODE
        LIMIT 1
    ];

    if (!existingEmployees.isEmpty()) {
        throw new LeaveTrackerException(
            'Employee code already exists.'
        );
    }
}
}