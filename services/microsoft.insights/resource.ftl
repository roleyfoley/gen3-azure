[#ftl]

[@addResourceProfile
  service=AZURE_INSIGHTS_SERVICE
  resource=AZURE_AUTOSCALE_SETTINGS_RESOURCE_TYPE
  profile=
    {
      "apiVersion" : "2018-05-01-preview",
      "type" : "Microsoft.Insights/autoscaleSettings"
    }
/]

[#assign AZURE_AUTOSCALE_SETTINGS_OUTPUT_MAPPINGS =
  {
    REFERENCE_ATTRIBUTE_TYPE : {
      "Property" : "id"
    }
  }
]

[#assign outputMappings += 
  {
    AZURE_AUTOSCALE_SETTINGS_RESOURCE_TYPE : AZURE_AUTOSCALE_SETTINGS_OUTPUT_MAPPINGS
  }
]

[#function getAutoScaleRule
  metricName
  resourceId
  timeGrain
  statistic
  timeWindow
  timeAggregation
  operator
  threshold
  direction
  actionType
  cooldown
  actionValue=""]

  [#return
    {
      "metricTrigger" : {
        "metricName" : metricName,
        "metricResourceUri" : resourceId,
        "timeGrain" : timeGrain,
        "statistic" : statistic,
        "timeWindow" : timeWindow,
        "timeAggregation" : timeAggregation,
        "operator" : operator,
        "threshold" : threshold
      },
      "scaleAction" : {
        "direction" : direction,
        "type" : actionType,
        "cooldown" : cooldown
      } +
      attributeIfContent("value", actionValue)
    }
  ]

[/#function]

[#function getAutoScaleProfile
  name
  minCapacity
  maxCapacity
  defaultCapacity
  rules
  fixedDate={}
  recurrence={}]

  [#return 
    {
      "name" : name,
      "capacity" : {
        "minimum" : minCapacity,
        "maximum" : maxCapacity,
        "default" : defaultCapacity
      },
      "rules" : rules
    } +
    attributeIfContent("fixedDate", fixedDate) +
    attributeIfContent("recurrence", recurrence)
  ]

[/#function]

[#macro createAutoscaleSettings
  id
  name
  location
  targetId
  profiles
  notifications=[]
  outputs={}
  dependsOn=[]]

  [@armResource
    id=id
    name=name
    profile=AZURE_AUTOSCALE_SETTINGS_RESOURCE_TYPE
    location=location
    outputs=outputs
    dependsOn=dependsOn
    properties=
      {
        "name" : name,
        "profiles" : profiles,
        "targetResourceUri" : targetId
      } +
      attributeIfContent(""notifications", notifications) +
  /]

[/#macro]