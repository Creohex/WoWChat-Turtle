package wowchat.game

import java.net.InetSocketAddress
import java.util.concurrent.TimeUnit

import wowchat.common._
import com.typesafe.scalalogging.StrictLogging
import io.netty.bootstrap.Bootstrap
import io.netty.channel.{Channel, ChannelInitializer, ChannelOption}
import io.netty.channel.socket.SocketChannel
import io.netty.channel.socket.nio.NioSocketChannel
import io.netty.handler.timeout.IdleStateHandler
import io.netty.util.concurrent.Future

import scala.util.Try

class GameConnector(host: String,
                    port: Int,
                    realmName: String,
                    realmId: Int,
                    sessionKey: Array[Byte],
                    gameEventCallback: CommonConnectionCallback)
  extends GamePackets with StrictLogging {

  sys.addShutdownHook({
    disconnect
  })

  private var channel: Option[Channel] = None
  var handler: Option[GamePacketHandler] = None

  def connect: Unit = {
    if (channel.fold(false)(_.isActive)) {
      logger.error("Refusing to connect to game server. Connection already exists.")
      return
    }

    logger.info(s"Connecting to game server $realmName ($host:$port)")

    val bootstrap = new Bootstrap
    bootstrap.group(Global.group)
      .channel(classOf[NioSocketChannel])
      .option[java.lang.Integer](ChannelOption.CONNECT_TIMEOUT_MILLIS, 10000)
      .option[java.lang.Boolean](ChannelOption.SO_KEEPALIVE, true)
      .remoteAddress(new InetSocketAddress(host, port))
      .handler(new ChannelInitializer[SocketChannel]() {

        @throws[Exception]
        override protected def initChannel(socketChannel: SocketChannel): Unit = {
          // Always use classic/vanilla packet handlers regardless of server's reported realm_build
          val encoder = new GamePacketEncoder
          val decoder = new GamePacketDecoder

          socketChannel.attr(CRYPT).set(new GameHeaderCrypt)
          handler = Some(
            new GamePacketHandler(realmId, realmName, sessionKey, gameEventCallback)
          )

          socketChannel.pipeline.addLast(
            new IdleStateHandler(60, 120, 0),
            new IdleStateCallback,
            decoder,
            encoder,
            handler.get)
        }
      })

    channel = Some(bootstrap.connect.addListener((future: Future[_ >: Void]) => {
      Try {
        future.get(10, TimeUnit.SECONDS)
      }.fold(throwable => {
        logger.error(s"Failed to connect to game server! ${throwable.getMessage}")
        gameEventCallback.disconnected
      }, _ => Unit)
    }).channel)
  }

  def disconnect: Unit = {
    if (Global.group.isShuttingDown || Global.group.isShutdown || Global.group.isTerminated) {
      return
    }

    channel.foreach(channel => {
      handler.get.sendLogout.foreach(_.await)
      channel.close
    })
    channel = None
  }
}
