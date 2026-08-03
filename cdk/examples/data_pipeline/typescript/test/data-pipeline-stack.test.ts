import { App } from 'aws-cdk-lib'
import { Template } from 'aws-cdk-lib/assertions'
import { DataPipelineBlueprintStack } from '../lib/data-pipeline-stack'

test('passes the folder name to each ECS task as a JSONPath', () => {
  const app = new App()
  const stack = new DataPipelineBlueprintStack(app, 'DataPipelineTest')
  const template = Template.fromStack(stack).toJSON()
  const stateMachine = Object.values(template.Resources).find(
    (resource: any) => resource.Type === 'AWS::StepFunctions::StateMachine'
  ) as any
  const definitionParts = stateMachine.Properties.DefinitionString['Fn::Join'][1]
  const definition = definitionParts
    .filter((part: unknown) => typeof part === 'string')
    .join('')

  expect(definition).toContain(
    '"Name":"FOLDERNAME","Value.$":"$.foldername"'
  )
})
