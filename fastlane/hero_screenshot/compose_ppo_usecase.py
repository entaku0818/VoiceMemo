"""Generate the Japanese iPhone hero for the recording-usecase PPO treatment."""
from pathlib import Path
import compose

if __name__ == '__main__':
    compose.COPY['ja']['recorder'] = ('会議も講義も、', 'ワンタップで録音')
    destination = Path(__file__).resolve().parents[1] / 'screenshots_ppo/ja/recording-usecase/0_APP_IPHONE_67_0.png'
    destination.parent.mkdir(parents=True, exist_ok=True)
    compose.v5('ja').save(destination, 'PNG')
    print(destination)
