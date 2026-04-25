import { AccessToken } from 'livekit-server-sdk'
import { RoomAgentDispatch, RoomConfiguration } from '@livekit/protocol'
import { z } from 'zod'
import { type Handlers, type StepConfig, http, logger } from 'motia'

export const config = {
  name: 'generate-livekit-token',
  description: 'Generates a LiveKit JWT with optional agent dispatch',
  triggers: [
    http('POST', '/auth/token', {
      bodySchema: z.object({
        room_name: z.string().min(1),
        participant_name: z.string().min(1),
        agent_name: z.string().optional(),
      }),
      responseSchema: {
        200: z.object({
          success: z.boolean(),
          token: z.string(),
          room: z.string(),
          identity: z.string(),
        }),
        500: z.object({ error: z.string() }),
      },
    }),
  ],
} as const satisfies StepConfig

export const handler: Handlers<typeof config> = async ({ request }) => {
  const { room_name, participant_name, agent_name } = request.body

  const apiKey = process.env.LIVEKIT_API_KEY ?? 'API1fij8kannxi8'
  const apiSecret = process.env.LIVEKIT_API_SECRET ?? 'e8w5qqiy74w4cxiauuzgkkcglhkawryo3x96ljbtaw2f'

  if (!apiKey || !apiSecret) {
    logger.error('LiveKit credentials missing from environment')
    return {
      status: 500,
      body: { error: 'Server configuration error' },
    }
  }

  try {
    const at = new AccessToken(apiKey, apiSecret, {
      identity: participant_name,
    })

    at.addGrant({
      room: room_name,
      roomJoin: true,
      canPublish: true,
      canSubscribe: true,
    })

    if (agent_name) {
      at.roomConfig = new RoomConfiguration({
        agents: [
          new RoomAgentDispatch({
            agentName: agent_name,
          }),
        ],
      })
      logger.info('Token generated with agent dispatch', { agent_name })
    }

    const token = await at.toJwt()

    return {
      status: 200,
      body: {
        success: true,
        token: token,
        room: room_name,
        identity: participant_name,
      },
    }
  } catch (error) {
    logger.error('Failed to generate LiveKit token', { error })
    return {
      status: 500,
      body: { error: 'Internal server error' },
    }
  }
}
