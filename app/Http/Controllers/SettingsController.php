<?php

namespace App\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;
use LibreNMS\Util\DynamicConfig;

class SettingsController extends Controller
{
    /**
     * Display a listing of the resource.
     *
     * @param  DynamicConfig  $dynamicConfig
     * @param  string  $tab
     * @param  string  $section
     * @return \Illuminate\Http\Response|\Illuminate\View\View
     */
    public function index(DynamicConfig $dynamicConfig, $tab = 'alerting', $section = '')
    {
        $data = [
            'active_tab' => $tab,
            'active_section' => $section,
            'groups' => $dynamicConfig->getGroups()->reject(fn ($group) => $group == 'global')->values(),
        ];

        return view('settings.index', $data);
    }

    /**
     * Update the specified resource in storage.
     *
     * @param  DynamicConfig  $config
     * @param  Request  $request
     * @param  string  $id
     * @return JsonResponse
     */
    public function update(DynamicConfig $config, Request $request, $id)
    {
        $value = $request->get('value');

        if (! $config->isValidSetting($id)) {
            return $this->jsonResponse($id, ':id is not a valid setting', null, 400);
        }

        $current = \App\Facades\LibrenmsConfig::get($id);
        $config_item = $config->get($id);

        if (! $config_item->checkValue($value)) {
            return $this->jsonResponse($id, $config_item->getValidationMessage($value), $current, 400);
        }

        if (\App\Facades\LibrenmsConfig::persist($id, $value)) {
            return $this->jsonResponse($id, "Successfully set $id", $value);
        }

        return $this->jsonResponse($id, 'Failed to update :id', $current, 400);
    }

    /**
     * Validate a setting key/value without persisting.
     *
     * @param  DynamicConfig  $config
     * @param  Request  $request
     * @param  string  $id
     * @return JsonResponse
     */
    public function validateSetting(DynamicConfig $config, Request $request, $id)
    {
        if (! $config->isValidSetting($id)) {
            return $this->validationResponse(':id is not a valid setting', 400);
        }

        $config_item = $config->get($id);
        $scope = $request->get('scope', 'value');
        $key = $request->get('key');
        $parent = $request->get('parent');
        $value = $request->get('value');

        switch ($config_item->type) {
            case 'map':
                if (! $config_item->checkKey($key)) {
                    return $this->validationResponse($config_item->getKeyValidationMessage($key));
                }

                return $this->validateValueWithRules([$key => $value], $config_item->validate);

            case 'nested-map':
                if ($scope === 'key') {
                    if (! $config_item->checkKey($key)) {
                        return $this->validationResponse($config_item->getValidationMessage([$key => []]));
                    }

                    return response()->json(['valid' => true]);
                }

                if (! $parent) {
                    return $this->validationResponse(__('settings.validate.missing_parent'));
                }

                if (! $config_item->checkKey($key)) {
                    return $this->validationResponse($config_item->getKeyValidationMessage($key));
                }

                return $this->validateValueWithRules([$parent => [$key => $value]], $config_item->validate);

            default:
                if (! $config_item->checkValue($value)) {
                    return $this->validationResponse($config_item->getValidationMessage($value));
                }

                return response()->json(['valid' => true]);
        }
    }

    /**
     * Remove the specified resource from storage.
     *
     * @param  DynamicConfig  $config
     * @param  string  $id
     * @return JsonResponse
     */
    public function destroy(DynamicConfig $config, $id)
    {
        if (! $config->isValidSetting($id)) {
            return $this->jsonResponse($id, ':id is not a valid setting', null, 400);
        }

        $dbConfig = \App\Models\Config::withChildren($id)->get();
        if ($dbConfig->isEmpty()) {
            return $this->jsonResponse($id, ':id is not set', $config->get($id)->default, 400);
        }

        $dbConfig->each->delete();

        return $this->jsonResponse($id, ':id reset to default', $config->get($id)->default);
    }

    /**
     * List all settings (excluding hidden ones and ones that don't have metadata)
     *
     * @param  DynamicConfig  $config
     * @return JsonResponse
     */
    public function listAll(DynamicConfig $config)
    {
        return response()->json($config->all()->filter->isValid());
    }

    /**
     * @param  string  $id
     * @param  string  $message
     * @param  mixed  $value
     * @param  int  $status
     * @return JsonResponse
     */
    protected function jsonResponse($id, $message, $value = null, $status = 200)
    {
        return new JsonResponse([
            'message' => __($message, ['id' => $id]),
            'value' => $value,
        ], $status);
    }

    protected function validationResponse(string $message, int $status = 422): JsonResponse
    {
        return new JsonResponse([
            'valid' => false,
            'message' => __($message),
        ], $status);
    }

    protected function validateValueWithRules($value, ?array $rules): JsonResponse
    {
        if (empty($rules)) {
            return response()->json(['valid' => true]);
        }

        $validator = Validator::make(['value' => $value], $rules);

        if ($validator->fails()) {
            return $this->validationResponse($validator->messages()->first());
        }

        return response()->json(['valid' => true]);
    }
}
