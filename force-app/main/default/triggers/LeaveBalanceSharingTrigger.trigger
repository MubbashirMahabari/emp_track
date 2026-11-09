trigger LeaveBalanceSharingTrigger on Leave_Balance__c (after insert) {

    Set<Id> employeeIds = new Set<Id>();

    for (Leave_Balance__c balance : Trigger.new) {
        if (balance.Employee__c != null) {
            employeeIds.add(balance.Employee__c);
        }
    }

    if (employeeIds.isEmpty()) {
        return;
    }

    // Retrieve the assigned managers for all employees.
    Map<Id, Employee__c> employeesById =
        new Map<Id, Employee__c>([
            SELECT Id, Manager__c
            FROM Employee__c
            WHERE Id IN :employeeIds
        ]);

    Set<Id> balanceIds = new Set<Id>();
    Set<Id> managerIds = new Set<Id>();

    for (Leave_Balance__c balance : Trigger.new) {
        Employee__c employee =
            employeesById.get(balance.Employee__c);

        if (employee != null && employee.Manager__c != null) {
            balanceIds.add(balance.Id);
            managerIds.add(employee.Manager__c);
        }
    }

    if (balanceIds.isEmpty()) {
        return;
    }

    // Find existing custom manager shares.
    List<Leave_Balance__Share> existingShares = [
        SELECT Id, ParentId, UserOrGroupId, AccessLevel
        FROM Leave_Balance__Share
        WHERE ParentId IN :balanceIds
        AND UserOrGroupId IN :managerIds
        AND RowCause =
            :Schema.Leave_Balance__Share.RowCause.Manager_Access__c
    ];

    Set<String> existingShareKeys = new Set<String>();

    List<Leave_Balance__Share> sharesToUpdate =
        new List<Leave_Balance__Share>();

    for (Leave_Balance__Share existingShare : existingShares) {

        String shareKey =
            String.valueOf(existingShare.ParentId) + '-' +
            String.valueOf(existingShare.UserOrGroupId);

        existingShareKeys.add(shareKey);

        if (existingShare.AccessLevel != 'Read') {
            existingShare.AccessLevel = 'Read';
            sharesToUpdate.add(existingShare);
        }
    }

    List<Leave_Balance__Share> sharesToInsert =
        new List<Leave_Balance__Share>();

    for (Leave_Balance__c balance : Trigger.new) {

        Employee__c employee =
            employeesById.get(balance.Employee__c);

        if (employee == null || employee.Manager__c == null) {
            continue;
        }

        String shareKey =
            String.valueOf(balance.Id) + '-' +
            String.valueOf(employee.Manager__c);

        if (!existingShareKeys.contains(shareKey)) {

            sharesToInsert.add(new Leave_Balance__Share(
                ParentId = balance.Id,
                UserOrGroupId = employee.Manager__c,
                AccessLevel = 'Read',
                RowCause =
                    Schema.Leave_Balance__Share.RowCause.Manager_Access__c
            ));
        }
    }

    if (!sharesToUpdate.isEmpty()) {
        update sharesToUpdate;
    }

    if (!sharesToInsert.isEmpty()) {
        insert sharesToInsert;
    }
}