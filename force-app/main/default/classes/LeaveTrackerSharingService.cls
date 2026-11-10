public without sharing class LeaveTrackerSharingService {

    /**
     * Grants the assigned manager Read access to an employee record.
     */
    public static void shareEmployeeWithManager(
        Id employeeId,
        Id managerId
    ) {

        if (employeeId == null || managerId == null) {
            throw new LeaveTrackerException(
                'Employee Id and Manager Id are required.'
            );
        }

        // Check whether the share already exists.
        List<Employee__Share> existingShares = [
            SELECT Id
            FROM Employee__Share
            WHERE ParentId = :employeeId
            AND UserOrGroupId = :managerId
            AND RowCause = :Schema.Employee__Share.RowCause.Manager_Access__c
            LIMIT 1
        ];

        if (!existingShares.isEmpty()) {
            return;
        }

        Employee__Share employeeShare = new Employee__Share(
            ParentId = employeeId,
            UserOrGroupId = managerId,
            AccessLevel = 'Read',
            RowCause = Schema.Employee__Share.RowCause.Manager_Access__c
        );

        insert employeeShare;
    }

    /**
 * Grants the assigned manager Edit access to a leave request.
 */
public static void shareLeaveRequestWithManager(
    Id leaveRequestId,
    Id managerId
) {
    if (leaveRequestId == null || managerId == null) {
        throw new LeaveTrackerException(
            'Leave Request Id and Manager Id are required.'
        );
    }

    List<Leave_Request__Share> existingShares = [
        SELECT Id, AccessLevel
        FROM Leave_Request__Share
        WHERE ParentId = :leaveRequestId
        AND UserOrGroupId = :managerId
        AND RowCause = :Schema.Leave_Request__Share.RowCause.Manager_Access__c
        LIMIT 1
    ];

    if (!existingShares.isEmpty()) {
        if (existingShares[0].AccessLevel != 'Edit') {
            existingShares[0].AccessLevel = 'Edit';
            update existingShares[0];
        }
        return;
    }

    insert new Leave_Request__Share(
        ParentId = leaveRequestId,
        UserOrGroupId = managerId,
        AccessLevel = 'Edit',
        RowCause = Schema.Leave_Request__Share.RowCause.Manager_Access__c
    );
}


/**
 * Grants the assigned manager Read access to a leave balance.
 */
public static void shareLeaveBalanceWithManager(
    Id leaveBalanceId,
    Id managerId
) {
    if (leaveBalanceId == null || managerId == null) {
        throw new LeaveTrackerException(
            'Leave Balance Id and Manager Id are required.'
        );
    }

    List<Leave_Balance__Share> existingShares = [
        SELECT Id, AccessLevel
        FROM Leave_Balance__Share
        WHERE ParentId = :leaveBalanceId
        AND UserOrGroupId = :managerId
        AND RowCause = :Schema.Leave_Balance__Share.RowCause.Manager_Access__c
        LIMIT 1
    ];

    if (!existingShares.isEmpty()) {
        if (existingShares[0].AccessLevel != 'Read') {
            existingShares[0].AccessLevel = 'Read';
            update existingShares[0];
        }
        return;
    }

    insert new Leave_Balance__Share(
        ParentId = leaveBalanceId,
        UserOrGroupId = managerId,
        AccessLevel = 'Read',
        RowCause = Schema.Leave_Balance__Share.RowCause.Manager_Access__c
    );
}


/**
 * Synchronizes manager access when an employee's manager changes.
 * Also reassigns pending leave requests to the new manager.
 */
public static void syncEmployeeManagerAccess(
    Id employeeId,
    Id oldManagerId,
    Id newManagerId
) {
    if (employeeId == null) {
        throw new LeaveTrackerException(
            'Employee Id is required.'
        );
    }

    // Retrieve all related leave requests.
    List<Leave_Request__c> requests = [
        SELECT Id, Manager__c, Status__c
        FROM Leave_Request__c
        WHERE Employee__c = :employeeId
    ];

    // Retrieve all related leave balances.
    List<Leave_Balance__c> balances = [
        SELECT Id
        FROM Leave_Balance__c
        WHERE Employee__c = :employeeId
    ];

    // Do not remove the old manager while pending requests
    // exist without assigning a replacement manager.
    if (newManagerId == null) {
        for (Leave_Request__c request : requests) {
            if (
                request.Status__c ==
                'Pending Manager Approval'
            ) {
                throw new LeaveTrackerException(
                    'Please assign a new manager before removing the current manager. Pending leave requests exist.'
                );
            }
        }
    }

    // Remove old manager's custom sharing access.
    if (
        oldManagerId != null &&
        oldManagerId != newManagerId
    ) {
        List<Employee__Share> employeeShares = [
            SELECT Id
            FROM Employee__Share
            WHERE ParentId = :employeeId
            AND UserOrGroupId = :oldManagerId
            AND RowCause =
                :Schema.Employee__Share.RowCause.Manager_Access__c
        ];

        if (!employeeShares.isEmpty()) {
            delete employeeShares;
        }

        Set<Id> requestIds = new Map<Id, Leave_Request__c>(
            requests
        ).keySet();

        if (!requestIds.isEmpty()) {
            List<Leave_Request__Share> requestShares = [
                SELECT Id
                FROM Leave_Request__Share
                WHERE ParentId IN :requestIds
                AND UserOrGroupId = :oldManagerId
                AND RowCause =
                    :Schema.Leave_Request__Share.RowCause.Manager_Access__c
            ];

            if (!requestShares.isEmpty()) {
                delete requestShares;
            }
        }

        Set<Id> balanceIds = new Map<Id, Leave_Balance__c>(
            balances
        ).keySet();

        if (!balanceIds.isEmpty()) {
            List<Leave_Balance__Share> balanceShares = [
                SELECT Id
                FROM Leave_Balance__Share
                WHERE ParentId IN :balanceIds
                AND UserOrGroupId = :oldManagerId
                AND RowCause =
                    :Schema.Leave_Balance__Share.RowCause.Manager_Access__c
            ];

            if (!balanceShares.isEmpty()) {
                delete balanceShares;
            }
        }
    }

    // No new manager means there is nothing more to share.
    if (newManagerId == null) {
        return;
    }

    // Grant the new manager Employee Read access.
    shareEmployeeWithManager(
        employeeId,
        newManagerId
    );

    // Reassign pending requests to the new manager.
    List<Leave_Request__c> requestsToUpdate =
        new List<Leave_Request__c>();

    for (Leave_Request__c request : requests) {
        if (
            request.Status__c ==
            'Pending Manager Approval'
        ) {
            if (request.Manager__c != newManagerId) {
                request.Manager__c = newManagerId;
                requestsToUpdate.add(request);
            }

            // Pending requests require Edit access.
            shareLeaveRequestWithManager(
                request.Id,
                newManagerId
            );
        } else {
            // Historical requests receive Read access.
            Leave_Request__Share historicalShare =
                new Leave_Request__Share(
                    ParentId = request.Id,
                    UserOrGroupId = newManagerId,
                    AccessLevel = 'Read',
                    RowCause =
                        Schema.Leave_Request__Share.RowCause.Manager_Access__c
                );

            insert historicalShare;
        }
    }

    if (!requestsToUpdate.isEmpty()) {
        update requestsToUpdate;
    }

    // Grant the new manager Read access to leave balances.
    for (Leave_Balance__c balance : balances) {
        shareLeaveBalanceWithManager(
            balance.Id,
            newManagerId
        );
    }
}
}