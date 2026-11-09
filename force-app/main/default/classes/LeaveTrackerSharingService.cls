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

    // Remove the previous manager's custom share.
    if (
        oldManagerId != null &&
        oldManagerId != newManagerId
    ) {
        List<Employee__Share> oldShares = [
            SELECT Id
            FROM Employee__Share
            WHERE ParentId = :employeeId
            AND UserOrGroupId = :oldManagerId
            AND RowCause =
                :Schema.Employee__Share.RowCause.Manager_Access__c
        ];

        if (!oldShares.isEmpty()) {
            delete oldShares;
        }
    }

    // Grant access to the newly assigned manager.
    if (newManagerId != null) {
        shareEmployeeWithManager(
            employeeId,
            newManagerId
        );
    }
}
}