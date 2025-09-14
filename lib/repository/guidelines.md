FunctionDeclaration(
  'updateLatestRecord',
  'Update the most recent record of an activity. If recordId is provided, update that specific record instead',
  parameters: <String, Schema>{
    'activityName': Schema.string(description: 'Name of the activity to update'),
    'updates': Schema.object(
      description: 'Fields to update in the record',
      properties: {
        'startStr': Schema.string(
          description: 'New start time for time-based records (format: yyyy-MM-dd HH:mm:ss)',
          nullable: true,
        ),
        'endStr': Schema.string(
          description: 'New end time for time-based records (format: yyyy-MM-dd HH:mm:ss)',
          nullable: true,
        ),
        'productiveMinutes': Schema.number(
          description: 'New productive minutes for time-based records',
          nullable: true,
        ),
        'timestampStr': Schema.string(
          description: 'New timestamp for count-based records (format: yyyy-MM-dd HH:mm:ss)',
          nullable: true,
        ),
        'count': Schema.number(
          description: 'New count value for count-based records',
          nullable: true,
        ),
      },
    ),
    'recordId': Schema.string(
      description: 'Specific record ID to update (optional). If not provided, updates the latest record',
      nullable: true,
    ),
  },
),
