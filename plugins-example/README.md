# NetBox Plugins

This directory is for custom NetBox plugins development.

## Plugin Development

### Creating a New Plugin

1. Create a new directory for your plugin:
   ```bash
   mkdir -p plugins-example/my_plugin
   ```

2. Create the plugin structure:
   ```
   my_plugin/
   ├── __init__.py
   ├── navigation.py
   ├── urls.py
   ├── views.py
   ├── models.py
   ├── api/
   │   ├── __init__.py
   │   ├── serializers.py
   │   └── views.py
   └── templates/
       └── my_plugin/
   ```

3. Define your plugin in `__init__.py`:
   ```python
   from netbox.plugins import PluginConfig

   class MyPluginConfig(PluginConfig):
       name = 'my_plugin'
       verbose_name = 'My Plugin'
       description = 'Description of my plugin'
       version = '0.1.0'
       author = 'Your Name'
       author_email = 'your.email@example.com'
       base_url = 'my-plugin'
       required_settings = []
       default_settings = {}

   config = MyPluginConfig
   ```

4. Add your plugin to requirements.txt if it's a package, or mount it as a volume.

### Installing Plugins

#### Method 1: Using Custom Docker Image

Create a Dockerfile:
```dockerfile
FROM netboxcommunity/netbox:latest

COPY plugins-example/requirements.txt /tmp/requirements.txt
RUN pip install -r /tmp/requirements.txt

COPY plugins-example/ /opt/netbox/netbox/plugins/
```

Build and push:
```bash
docker build -t your-registry/netbox-custom:latest .
docker push your-registry/netbox-custom:latest
```

Update the deployment image in your overlay.

#### Method 2: Using ConfigMap (for development)

Create a ConfigMap with your plugin code:
```bash
oc create configmap my-plugin-code --from-file=plugins-example/my_plugin/ -n netbox-dev
```

Update the deployment to mount it:
```yaml
volumeMounts:
  - name: plugin-code
    mountPath: /opt/netbox/netbox/plugins/my_plugin
volumes:
  - name: plugin-code
    configMap:
      name: my-plugin-code
```

### Configuring Plugins

Update the NetBox ConfigMap to enable your plugin:

```yaml
# k8s/base/netbox/configmap.yaml or in overlays
data:
  PLUGINS: "['my_plugin']"
  PLUGINS_CONFIG: |
    {
      "my_plugin": {
        "option1": "value1",
        "option2": "value2"
      }
    }
```

## Testing Plugins

1. Deploy to dev environment
2. Access the NetBox pod:
   ```bash
   oc exec -it -n netbox-dev deployment/dev-netbox -- /bin/bash
   ```
3. Test your plugin:
   ```bash
   cd /opt/netbox/netbox
   python3 manage.py shell
   ```

## Resources

- [NetBox Plugin Development Documentation](https://docs.netbox.dev/en/stable/plugins/development/)
- [NetBox Plugin Tutorial](https://github.com/netbox-community/netbox-plugin-tutorial)
- [Example Plugins](https://github.com/netbox-community/netbox/wiki/Plugins)
