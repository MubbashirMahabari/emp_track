public with sharing class LeaveApprovalService {

@AuraEnabled
public static Leave_Request__c approveLeaveRequest(
    Id leaveRequestId
) {
    try {

        if (!FeatureManagement.checkPermission(
            'ELT_Approve_Leave'
        )) {
            throw new LeaveTrackerException(
                'You are not authorized to approve leave requests.'
            );
        }

        if (leaveRequestId == null) {
            throw new LeaveTrackerException(
                'Leave request Id is required.'
            );
        }

Leave_Request__c leaveRequest = [
    SELECT
        Id,
        Employee__c,
        Manager__c,
        From_Date__c,
        To_Date__c,
        Leave_Type__c,
        Total_Days__c,
        Status__c,
        Manager_Comment__c,
        Decision_Date__c
    FROM Leave_Request__c
    WHERE Id = :leaveRequestId
    WITH USER_MODE
    LIMIT 1
];

        if (leaveRequest.Manager__c != UserInfo.getUserId()) {
            throw new LeaveTrackerException(
                'You are not the assigned manager for this leave request.'
            );
        }

        if (leaveRequest.Status__c != 'Pending Manager Approval') {
            throw new LeaveTrackerException(
                'Only pending leave requests can be approved.'
            );
        }
        // NEW: Verify available leave balance
        validateLeaveBalance(leaveRequest);

        // Approve only after all validations pass
        leaveRequest.Status__c = 'Approved';

        leaveRequest.Decision_Date__c = Date.today();

        update as user leaveRequest;

        return leaveRequest;

    } catch (LeaveTrackerException e) {

        AuraHandledException ex =
            new AuraHandledException(e.getMessage());

        ex.setMessage(e.getMessage());

        throw ex;

    } catch (Exception e) {

    System.debug(
        LoggingLevel.ERROR,
        'ERROR TYPE: ' + e.getTypeName()
    );

    System.debug(
        LoggingLevel.ERROR,
        'ERROR MESSAGE: ' + e.getMessage()
    );

    System.debug(
        LoggingLevel.ERROR,
        'ERROR LINE: ' + e.getLineNumber()
    );

    AuraHandledException ex =
        new AuraHandledException(
            e.getMessage()
        );

    ex.setMessage(e.getMessage());

    throw ex;
}
}

@AuraEnabled
public static Leave_Request__c rejectLeaveRequest(
    Id leaveRequestId,
    String managerComment
) {
    try {

        if (!FeatureManagement.checkPermission(
            'ELT_Reject_Leave'
        )) {
            throw new LeaveTrackerException(
                'You are not authorized to reject leave requests.'
            );
        }

        if (leaveRequestId == null) {
            throw new LeaveTrackerException(
                'Leave request Id is required.'
            );
        }

        if (String.isBlank(managerComment)) {
            throw new LeaveTrackerException(
                'Manager comment is required when rejecting a leave request.'
            );
        }

      Leave_Request__c leaveRequest = [
    SELECT
        Id,
        Manager__c,
        Status__c,
        Decision_Date__c
    FROM Leave_Request__c
    WHERE Id = :leaveRequestId
    WITH USER_MODE
    LIMIT 1
];

        if (leaveRequest.Manager__c != UserInfo.getUserId()) {
            throw new LeaveTrackerException(
                'You are not the assigned manager for this leave request.'
            );
        }

        if (leaveRequest.Status__c != 'Pending Manager Approval') {
            throw new LeaveTrackerException(
                'Only pending leave requests can be rejected.'
            );
        }

        leaveRequest.Status__c = 'Rejected';

        leaveRequest.Manager_Comment__c =
            managerComment.trim();

        leaveRequest.Decision_Date__c =
            Date.today();

        update as user leaveRequest;

        return leaveRequest;

    } catch (LeaveTrackerException e) {

        AuraHandledException ex =
            new AuraHandledException(e.getMessage());

        ex.setMessage(e.getMessage());

        throw ex;

    } catch (Exception e) {

        AuraHandledException ex =
            new AuraHandledException(
                'Unable to reject leave request.'
            );

        ex.setMessage(
            'Unable to reject leave request.'
        );

        throw ex;
    }
}

private static void validateLeaveBalance(
    Leave_Request__c leaveRequest
) {

    String balanceField;

    // Step 1: Identify the leave category
    if (leaveRequest.Leave_Type__c == 'Casual Leave') {
        balanceField = 'Casual_Leave__c';

    } else if (leaveRequest.Leave_Type__c == 'Sick Leave') {
        balanceField = 'Sick_Leave__c';

    } else if (leaveRequest.Leave_Type__c == 'Annual Leave') {
        balanceField = 'Annual_Leave__c';

    } else {
        return;
    }

    // Step 2: Get entitlement year from leave start date
    Integer leaveYear = leaveRequest.From_Date__c.year();

    String yearValue = String.valueOf(leaveYear);

    // Step 3: Retrieve and lock employee balance
    List<Leave_Balance__c> balances = [
        SELECT
            Id,
            Employee__c,
            Year__c,
            Casual_Leave__c,
            Sick_Leave__c,
            Annual_Leave__c
        FROM Leave_Balance__c
        WHERE Employee__c = :leaveRequest.Employee__c
        AND Year__c = :yearValue
        WITH USER_MODE
        LIMIT 1
        FOR UPDATE
    ];

    if (balances.isEmpty()) {
        throw new LeaveTrackerException(
            'Leave balance not found for employee for year ' +
            yearValue + '.'
        );
    }

    Leave_Balance__c balance = balances[0];

    // Step 4: Get category entitlement
    Decimal entitlement = 0;

    if (balanceField == 'Casual_Leave__c') {
        entitlement = balance.Casual_Leave__c;

    } else if (balanceField == 'Sick_Leave__c') {
        entitlement = balance.Sick_Leave__c;

    } else if (balanceField == 'Annual_Leave__c') {
        entitlement = balance.Annual_Leave__c;
    }

    if (entitlement == null) {
        entitlement = 0;
    }

    // Step 5: Calculate previously approved leave
    AggregateResult[] results = [
        SELECT SUM(Total_Days__c) totalUsed
        FROM Leave_Request__c
        WHERE Employee__c = :leaveRequest.Employee__c
        AND Leave_Type__c = :leaveRequest.Leave_Type__c
        AND Status__c = 'Approved'
        AND CALENDAR_YEAR(From_Date__c) = :leaveYear
        WITH USER_MODE
    ];

    Decimal usedDays =
        (Decimal) results[0].get('totalUsed');

    if (usedDays == null) {
        usedDays = 0;
    }

    // Step 6: Calculate available and requested days
    Decimal availableDays = entitlement - usedDays;

    Decimal requestedDays = leaveRequest.Total_Days__c;

    // Step 7: Validate
    if (requestedDays > availableDays) {
        throw new LeaveTrackerException(
            'Insufficient ' + leaveRequest.Leave_Type__c +
            '. Available: ' + availableDays +
            ' days, Requested: ' + requestedDays + ' days.'
        );
    }
}
}